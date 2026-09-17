import AppKit
import SwiftUI

extension Notification.Name {
    /// 第二个实例启动时，用它叫醒已经在跑的那个。
    static let sitizenShowSettings = Notification.Name("com.sitizen.app.showSettings")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private enum DefaultsKey {
        static let onboardingDone = "onboardingDone"
    }

    private var settings: SettingsStore!
    private var state: AppState!
    private var overlays: OverlayCoordinator!
    private var menuBar: MenuBarController!
    private var settingsWindow: NSWindow?
    private var secondLaunchObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 已经有实例在跑：把它叫出来，然后自己安静退出。
        if handOffToExistingInstance() { return }

        settings = SettingsStore.shared
        state = AppState(settings: settings)
        overlays = OverlayCoordinator(state: state, settings: settings)
        menuBar = MenuBarController(state: state, settings: settings)

        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBar.onPreviewWarning = { [weak self] in self?.state.previewWarning() }
        menuBar.onPreviewLock = { [weak self] in self?.state.previewLock() }

        // 启动即开始计时：打开电脑就意味着你已经在坐着了。
        state.start()

        // 别的实例双击启动时会通知我们弹设置窗口。
        secondLaunchObserver = DistributedNotificationCenter.default().addObserver(
            forName: .sitizenShowSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.openSettings()
            }
        }

        // 这是个没有 Dock 图标的菜单栏 App，第一次启动必须给点反馈，
        // 否则用户双击之后只会觉得「点了没反应」。
        if !UserDefaults.standard.bool(forKey: DefaultsKey.onboardingDone) {
            UserDefaults.standard.set(true, forKey: DefaultsKey.onboardingDone)
            openSettings()
        }
    }

    // 双击已经在运行的 App，或从 Dock / Finder 再次打开时，弹出设置窗口。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - 设置窗口

    func openSettings() {
        guard settings != nil else { return }
        NSApp.activate(ignoringOtherApps: true)

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = SettingsWindowFactory.make(
            settings: settings,
            state: state,
            onPreviewWarning: { [weak self] in self?.state.previewWarning() },
            onPreviewLock: { [weak self] in self?.state.previewLock() },
            onQuit: { NSApp.terminate(nil) }
        )
        window.delegate = self

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == settingsWindow else { return }
        settingsWindow = nil
    }

    // MARK: - 单实例

    /// 如果已经有 Sitizen 在跑，通知它弹出设置窗口，然后本进程直接退出。
    /// 返回 `true` 表示本进程应该结束。
    private func handOffToExistingInstance() -> Bool {
        guard AppInfo.isBundled, let bundleID = Bundle.main.bundleIdentifier else { return false }

        // 只认「还活着」的实例。LaunchServices 偶尔会残留刚被 kill 掉的条目，
        // 不做这个过滤的话，新实例会误判成重复启动然后自己退出。
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .filter { !$0.isTerminated }
        guard !others.isEmpty else { return false }

        DistributedNotificationCenter.default().post(
            name: .sitizenShowSettings,
            object: nil,
            userInfo: nil
        )

        // 给通知一点时间真的发出去，再退出。
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        NSApp.terminate(nil)
        return true
    }
}
