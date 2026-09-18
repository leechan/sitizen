import AppKit
import Foundation

/// 开发 / CI 用：把久坐 → 预警 → 锁屏 → 起立 的完整节奏压缩到十几秒跑一遍。
///
///   Sitizen --selftest
enum SelfTest {

    @MainActor
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--selftest") else { return false }

        SoundPlayer.isMuted = true
        let defaults = UserDefaults(suiteName: "com.sitizen.selftest") ?? .standard
        defaults.removePersistentDomain(forName: "com.sitizen.selftest")

        let settings = SettingsStore(defaults: defaults)
        settings.sitMinutes = 0.05        // 3 秒
        settings.standMinutes = 0.05      // 3 秒
        settings.warningSeconds = 1
        settings.soundEnabled = false
        settings.autoPauseWhenAway = false

        let state = AppState(settings: settings)
        var failures: [String] = []
        var trace: [(t: Double, text: String)] = []

        let started = Date()
        var lastPhase = state.phase
        var lastOverlay = state.overlay
        trace.append((0, "起点 \(describe(state))"))

        func pump(_ seconds: TimeInterval) {
            let until = Date().addingTimeInterval(seconds)
            while Date() < until {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
                if state.phase != lastPhase || state.overlay != lastOverlay {
                    lastPhase = state.phase
                    lastOverlay = state.overlay
                    trace.append((Date().timeIntervalSince(started), describe(state)))
                }
            }
        }

        // 1. 正常跑完一轮：久坐 → 预警 → 锁屏 → 回到久坐
        state.start()
        pump(3.4)
        expect(state.phase == .warning || state.phase == .standing, "3.4 秒后应该已经进入预警或锁屏，实际 \(state.phase)", into: &failures)

        pump(1.0)
        expect(state.phase == .standing, "预警结束后应该锁屏，实际 \(state.phase)", into: &failures)
        expect(state.overlay == .lock, "锁屏时 overlay 应为 .lock，实际 \(String(describing: state.overlay))", into: &failures)

        pump(3.2)
        expect(state.phase == .sitting, "休息结束后应该回到久坐，实际 \(state.phase)", into: &failures)
        expect(state.overlay == nil, "回到久坐后不应有浮层，实际 \(String(describing: state.overlay))", into: &failures)
        expect(state.completedBreaks >= 1, "应至少完成 1 次起立，实际 \(state.completedBreaks)", into: &failures)

        // 2. 认输：锁屏状态下提前解锁
        state.standUpNow()
        pump(0.3)
        expect(state.overlay == .lock, "standUpNow 后应该锁屏", into: &failures)
        state.surrender()
        pump(0.3)
        expect(state.phase == .sitting, "认输后应该回到久坐，实际 \(state.phase)", into: &failures)
        expect(state.overlay == nil, "认输后浮层应消失", into: &failures)

        // 3. 暂停 / 恢复
        state.pause()
        pump(0.3)
        expect(state.phase == .idle, "暂停后应为 idle，实际 \(state.phase)", into: &failures)
        let frozen = state.remaining
        pump(0.5)
        expect(abs(state.remaining - frozen) < 0.01, "暂停期间剩余时间不应该变化", into: &failures)
        state.start()
        pump(0.3)
        expect(state.phase != .idle, "恢复后不应还是 idle", into: &failures)

        // 4. 试看
        state.endPreview()
        state.previewWarning()
        pump(0.2)
        expect(state.overlay == .warning, "试看预警时应显示预警浮层", into: &failures)
        state.endPreview()
        pump(0.2)
        expect(state.overlay != .warning, "结束试看后预警浮层应消失", into: &failures)

        // 5. 边界：久坐时长短于预警时长也不能卡死
        settings.sitMinutes = 0.02   // 1.2 秒 < 预警 1 秒 + 余量
        state.reset()
        state.start()
        pump(2.6)
        expect(state.phase == .standing || state.phase == .sitting, "极端时长下状态机不能卡死，实际 \(state.phase)", into: &failures)

        // 6. 运行中修改久坐时长：按新值重新计时（@Published 是 willSet，容易读到旧值）
        settings.sitMinutes = 0.05
        state.reset()
        state.start()
        pump(0.4)
        settings.sitMinutes = 0.2    // 12 秒
        pump(0.3)
        expect(state.remaining > 10, "改久坐时长后应按新值重新计时，实际 \(String(format: "%.1f", state.remaining))s", into: &failures)

        // 7. 「重新开始本轮」应该重置并立刻进入倒计时，而不是停在待开始
        state.pause()
        pump(0.3)
        state.restart()
        pump(0.5)
        expect(state.phase != .idle, "restart 后不应停在 idle，实际 \(state.phase)", into: &failures)
        expect(state.remaining < settings.sitMinutes * 60, "restart 后倒计时应该已经在走", into: &failures)

        // 8. 开启「休息结束后停留」：站满后应停在锁屏页，点一下才进入下一轮
        settings.stayUntilDismissed = true
        settings.standMinutes = 0.05   // 3 秒
        state.reset()
        state.standUpNow()
        pump(3.4)
        expect(state.phase == .awaitingDismiss, "站满后应停在待确认状态，实际 \(state.phase)", into: &failures)
        expect(state.overlay == .lock, "待确认期间锁屏浮层不应消失", into: &failures)
        expect(state.isAwaitingDismiss, "isAwaitingDismiss 应为 true", into: &failures)

        pump(1.5)
        expect(state.phase == .awaitingDismiss, "不点按钮就应该一直停着", into: &failures)

        state.dismissBreak()
        pump(0.4)
        expect(state.phase == .sitting, "点确认后应进入下一轮久坐，实际 \(state.phase)", into: &failures)
        expect(state.overlay == nil, "进入久坐后浮层应消失", into: &failures)

        // 关掉开关后回到自动开始
        settings.stayUntilDismissed = false
        state.reset()
        state.standUpNow()
        pump(3.4)
        expect(state.phase == .sitting, "关闭该选项后站满应自动开始下一轮，实际 \(state.phase)", into: &failures)

        print("── Sitizen 自检 ──")
        for entry in trace {
            print(String(format: "  %6.2fs  %@", entry.t, entry.text))
        }
        print("")
        if failures.isEmpty {
            print("✅ 全部通过")
            return true
        }
        print("❌ 失败 \(failures.count) 项：")
        failures.forEach { print("   · \($0)") }
        exit(1)
    }

    @MainActor
    private static func describe(_ state: AppState) -> String {
        let overlay: String
        switch state.overlay {
        case .warning: overlay = "预警浮层"
        case .lock: overlay = "锁屏浮层"
        case nil: overlay = "无浮层"
        }
        return String(format: "%-8@ 剩余 %.1fs  %@", phaseName(state.phase), state.remaining, overlay)
    }

    private static func phaseName(_ phase: AppState.Phase) -> String {
        switch phase {
        case .idle: return "idle"
        case .sitting: return "sitting"
        case .warning: return "warning"
        case .standing: return "standing"
        case .awaitingDismiss: return "awaiting"
        }
    }

    private static func expect(_ condition: Bool, _ message: String, into failures: inout [String]) {
        if !condition {
            failures.append(message)
        }
    }
}
