import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let state: AppState
    private let settings: SettingsStore
    private var uiTimer: Timer?
    private weak var headerItem: NSMenuItem?
    private var lastKey = ""

    var onOpenSettings: (() -> Void)?
    var onPreviewWarning: (() -> Void)?
    var onPreviewLock: (() -> Void)?

    init(state: AppState, settings: SettingsStore) {
        self.state = state
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = MenuBarIcon.make(width: 17)
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.imageHugsTitle = true
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // 定时器必须挂在 .common 上。菜单弹出时 run loop 会切到 eventTracking 模式，
        // 而 Combine 的 `receive(on: RunLoop.main)` 只在 .default 模式投递，
        // 那样菜单一展开倒计时就会「冻住」。
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.uiTimer = timer

        refresh()
    }

    deinit {
        uiTimer?.invalidate()
    }

    // MARK: - 刷新菜单栏标题

    private func refresh() {
        let header = headerText()
        let key = "\(header)|\(clock(state.displayRemaining))"
        guard key != lastKey else { return }
        lastKey = key

        updateTitle()
        // 菜单展开时同步刷新表头，免得停在打开那一刻的数字上。
        headerItem?.title = header
    }

    private func updateTitle() {
        let phase = state.displayPhase
        let text = clock(state.displayRemaining)

        let tint: NSColor
        switch phase {
        case .warning, .standing, .awaitingDismiss: tint = NSColor(Palette.accent)
        case .idle: tint = .secondaryLabelColor
        case .sitting: tint = .labelColor
        }

        statusItem.button?.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold),
                .foregroundColor: tint
            ]
        )
        statusItem.button?.toolTip = "Sitizen · \(state.statusHeadline)"
    }

    private func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - 菜单

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: headerText(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        headerItem = header
        menu.addItem(header)

        menu.addItem(.separator())

        if state.phase == .awaitingDismiss {
            menu.addItem(item("开始下一轮久坐", #selector(dismissBreak), key: "p"))
        } else {
            let toggleTitle = state.phase == .idle ? "开始" : "暂停"
            menu.addItem(item(toggleTitle, #selector(toggle), key: "p"))
        }
        menu.addItem(item("现在就去站一会儿", #selector(standUpNow), key: "s"))
        menu.addItem(item("重新开始本轮", #selector(restartRound), key: "r"))

        menu.addItem(.separator())

        if state.isPreviewing {
            menu.addItem(item("结束演示", #selector(endPreview), key: ""))
        } else {
            menu.addItem(item("演示：预警效果", #selector(previewWarning), key: ""))
            menu.addItem(item("演示：锁屏效果", #selector(previewLock), key: ""))
        }

        menu.addItem(.separator())

        menu.addItem(item("设置…", #selector(openSettings), key: ","))

        let about = NSMenuItem(title: "关于 Sitizen", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 Sitizen", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func headerText() -> String {
        switch state.phase {
        case .idle:
            return state.remaining > 0 ? "已暂停 · 还剩 \(clock(state.remaining))" : "准备就绪 · 待开始"
        case .sitting:
            return "坐着呢 · 还剩 \(clock(state.remaining))"
        case .warning:
            return "要起来了 · \(clock(state.remaining))"
        case .standing:
            return "站着呢 · 还剩 \(clock(state.remaining))"
        case .awaitingDismiss:
            return "休息结束 · 等你说开始"
        }
    }

    private func item(_ title: String, _ selector: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - 动作

    @objc private func toggle() {
        state.toggle()
        SoundPlayer.shared.play(.click)
    }

    @objc private func dismissBreak() {
        state.dismissBreak()
    }

    @objc private func standUpNow() {
        state.standUpNow()
    }

    @objc private func restartRound() {
        state.restart()
        SoundPlayer.shared.play(.click)
    }

    @objc private func endPreview() {
        state.endPreview()
    }

    @objc private func previewWarning() {
        onPreviewWarning?()
    }

    @objc private func previewLock() {
        onPreviewLock?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Sitizen \(AppInfo.version)"
        alert.informativeText = """
        \(AppInfo.tagline)。一个会让你的屁股和椅子分离的应用。

        默认 45 分钟久坐 + 5 分钟起立。
        最后 \(Int(settings.warningSeconds)) 秒全屏透明倒计时，到点直接锁屏。

        你坐出来的问题，只能靠站起来解决。

        作者：夜漫长

        特别感谢 kyc，他参与了 Sitizen 最早期版本的测试，并提出了宝贵功能建议。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.addButton(withTitle: "打开设置…")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            onOpenSettings?()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
