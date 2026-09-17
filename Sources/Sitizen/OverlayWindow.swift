import AppKit
import SwiftUI

/// 覆盖单块屏幕的无边框窗口。`interactive == false` 时完全不参与鼠标事件。
final class OverlayWindow: NSWindow {
    private let interactive: Bool

    init(screen: NSScreen, level: NSWindow.Level, interactive: Bool) {
        self.interactive = interactive
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = !interactive
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
        // 透明窗口不应该有系统阴影/圆角
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func setContent<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = hosting
        setFrame(screen?.frame ?? frame, display: false)
    }

    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { interactive }

    /// 拦截 ⌘Q / ⌘W / ⌘Tab 之类的快捷键。
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if interactive && event.modifierFlags.contains(.command) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        // 吞掉 Esc，别想跑。
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) { return }
        super.keyDown(with: event)
    }
}
