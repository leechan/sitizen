import AppKit
import Combine
import SwiftUI

/// 负责把 `AppState.Overlay` 映射成真实的浮层窗口（多显示器全覆盖）。
@MainActor
final class OverlayCoordinator {

    private let state: AppState
    private let settings: SettingsStore

    private var warningWindows: [OverlayWindow] = []
    private var lockWindows: [OverlayWindow] = []
    private var current: AppState.Overlay?
    private var cancellables = Set<AnyCancellable>()
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(state: AppState, settings: SettingsStore) {
        self.state = state
        self.settings = settings

        state.$overlay
            .receive(on: RunLoop.main)
            .sink { [weak self] overlay in
                self?.apply(overlay)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // queue: .main 保证在主线程回调，这里显式告诉编译器。
            MainActor.assumeIsolated {
                self?.rebuildIfNeeded()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 状态应用

    private func apply(_ overlay: AppState.Overlay?) {
        guard overlay != current else { return }
        current = overlay

        switch overlay {
        case .warning:
            tearDownLock()
            buildWarning()
        case .lock:
            tearDownWarning()
            buildLock()
        case nil:
            tearDownWarning()
            tearDownLock()
        }
    }

    private func rebuildIfNeeded() {
        guard let current else { return }
        switch current {
        case .warning:
            tearDownWarning()
            buildWarning()
        case .lock:
            tearDownLock()
            buildLock()
        }
    }

    // MARK: - 预警浮层

    private func buildWarning() {
        guard warningWindows.isEmpty else { return }
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen, level: .screenSaver, interactive: false)
            window.setContent(
                WarningView(state: state, settings: settings)
                    .frame(width: screen.frame.width, height: screen.frame.height)
            )
            window.orderFrontRegardless()
            warningWindows.append(window)
        }
    }

    private func tearDownWarning() {
        warningWindows.forEach { $0.orderOut(nil) }
        warningWindows.removeAll()
    }

    // MARK: - 锁屏浮层

    private func buildLock() {
        guard lockWindows.isEmpty else { return }

        let wasActive = NSWorkspace.shared.frontmostApplication
        if wasActive?.bundleIdentifier != AppInfo.bundleIdentifier {
            previousApp = wasActive
        }

        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let isPrimary = index == 0
            let window = OverlayWindow(screen: screen, level: .screenSaver, interactive: isPrimary)
            window.setContent(
                LockView(state: state, settings: settings, isPrimary: isPrimary)
                    .frame(width: screen.frame.width, height: screen.frame.height)
            )
            if isPrimary {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
            lockWindows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        installKeyTrap()
    }

    private func tearDownLock() {
        guard !lockWindows.isEmpty || keyMonitor != nil else { return }
        removeKeyTrap()
        lockWindows.forEach { $0.orderOut(nil) }
        lockWindows.removeAll()

        NSApp.deactivate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let previous = self.previousApp else { return }
            if previous.bundleIdentifier != AppInfo.bundleIdentifier, !previous.isTerminated {
                _ = previous.activate(from: NSRunningApplication.current, options: [])
            }
            self.previousApp = nil
        }
    }

    // MARK: - 键盘拦截

    private func installKeyTrap() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            // 锁屏期间吞掉一切带 ⌘ 的组合键与 Esc。
            if event.modifierFlags.contains(.command) { return nil }
            if event.keyCode == 53 { return nil }
            return event
        }
    }

    private func removeKeyTrap() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }
}
