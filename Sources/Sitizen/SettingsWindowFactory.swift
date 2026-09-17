import AppKit
import SwiftUI

enum SettingsWindowFactory {
    @MainActor
    static func make(
        settings: SettingsStore,
        state: AppState,
        onPreviewWarning: @escaping () -> Void,
        onPreviewLock: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) -> NSWindow {
        let root = SettingsView(
            settings: settings,
            state: state,
            onPreviewWarning: onPreviewWarning,
            onPreviewLock: onPreviewLock,
            onQuit: onQuit
        )

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Sitizen 设置"
        // 刻意不用 fullSizeContentView：让出真正的标题栏区域用来拖窗口，
        // 否则滚动视图会把标题栏上的拖动也吃掉。
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // 关闭「拖动背景移动窗口」：否则在滑杆/数值上拖动会把整个窗口带走。
        // 窗口仍然可以按住顶部标题栏区域拖动。
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor(PaperPalette.paper)
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 460, height: 640))
        center(window)
        return window
    }

    /// 显式地把窗口摆到鼠标所在那块屏幕的中间。
    /// 比 `NSWindow.center()` 更好预测，多显示器下不会跑到别的屏上。
    @MainActor
    private static func center(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )
        )
    }
}
