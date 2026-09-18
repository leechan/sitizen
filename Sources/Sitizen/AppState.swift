import Combine
import Foundation

/// 久坐 / 起立的循环状态机，是全局唯一的计时真相来源。
final class AppState: ObservableObject {

    enum Phase: Equatable {
        case idle       // 未开始 / 已暂停
        case sitting    // 久坐倒计时中
        case warning    // 最后 N 秒，全屏透明预警
        case standing   // 起立休息中，屏幕已锁定
        case awaitingDismiss   // 休息已站满，停在锁屏页等用户点一下
    }

    /// 当前需要展示的浮层类型。
    enum Overlay: Equatable {
        case warning
        case lock
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var overlay: Overlay?
    @Published private(set) var completedBreaks: Int = 0
    @Published private(set) var awayPaused: Bool = false
    @Published private(set) var previewRemaining: TimeInterval = 0

    let settings: SettingsStore

    private var deadline: Date?
    private var timer: Timer?
    private var pausedPhase: Phase = .sitting
    private var cancellables = Set<AnyCancellable>()
    private let watcher = SystemActivityWatcher()
    private var automaticallyPaused = false

    /// 预览用的沙盒倒计时，不影响真实节奏。
    private var previewKind: Overlay?
    private var previewHardDeadline: Date?
    private var previewsFinished = false

    init(settings: SettingsStore = .shared) {
        self.settings = settings
        self.remaining = settings.sitMinutes * 60

        // 注意：@Published 的 publisher 是在 willSet 里发值的，回调里直接读
        // settings.sitMinutes 会拿到旧值，所以这里把新值透传下去。
        settings.$sitMinutes
            .dropFirst()
            .sink { [weak self] minutes in self?.sitDurationChanged(minutes) }
            .store(in: &cancellables)

        settings.$standMinutes
            .dropFirst()
            .sink { [weak self] minutes in self?.standDurationChanged(minutes) }
            .store(in: &cancellables)

        watcher.onAway = { [weak self] in self?.handleAway() }
        watcher.onReturn = { [weak self] in self?.handleReturn() }

        startTicking()
    }

    // MARK: - 派生展示值（预览优先）

    var displayPhase: Phase {
        guard let previewKind else { return phase }
        return previewKind == .warning ? .warning : .standing
    }

    var displayRemaining: TimeInterval {
        previewKind == nil ? remaining : previewRemaining
    }

    /// 预警圆环的总时长
    var warningTotal: TimeInterval {
        max(1, settings.warningSeconds)
    }

    /// 休息圆环的总时长
    var standTotal: TimeInterval {
        max(1, settings.standMinutes * 60)
    }

    var isPreviewing: Bool { previewKind != nil }

    /// 休息站满了、停在锁屏页等用户点确认。
    var isAwaitingDismiss: Bool {
        previewKind != nil ? previewsFinished : phase == .awaitingDismiss
    }

    var isRunning: Bool { phase != .idle }

    var statusHeadline: String {
        switch phase {
        case .idle: return remaining > 0 ? "已暂停" : "准备就绪"
        case .sitting: return "坐着呢"
        case .warning: return "要起来了"
        case .standing: return "站着呢"
        case .awaitingDismiss: return "休息结束"
        }
    }

    // MARK: - 控制

    func start() {
        guard phase == .idle else { return }
        if remaining <= 1 {
            startSitting()
        } else {
            resume()
        }
    }

    func pause() {
        guard phase != .idle else { return }
        pausedPhase = phase
        remaining = max(0, deadline?.timeIntervalSinceNow ?? remaining)
        deadline = nil
        phase = .idle
        syncOverlay()
    }

    func toggle() {
        phase == .idle ? start() : pause()
    }

    func reset() {
        deadline = nil
        pausedPhase = .sitting
        phase = .idle
        remaining = settings.sitMinutes * 60
        automaticallyPaused = false
        awayPaused = false
        syncOverlay()
    }

    /// 重置本轮并立刻开始倒计时。
    func restart() {
        reset()
        start()
    }

    /// 休息结束后用户点了「开始下一轮」。
    func dismissBreak() {
        guard phase == .awaitingDismiss else { return }
        completedBreaks += 1
        SoundPlayer.shared.play(.click)
        startSitting()
    }

    /// 立刻进入起立休息（跳过剩余久坐时间）。
    func standUpNow() {
        startStanding()
    }

    /// 认输：提前结束休息，回到久坐。
    func surrender() {
        if previewKind != nil {
            endPreview()
            return
        }
        guard phase == .standing else { return }
        SoundPlayer.shared.play(.surrender)
        completedBreaks += 1
        startSitting()
    }

    // MARK: - 预览（设置面板里的试看）

    func previewWarning() {
        previewKind = .warning
        previewRemaining = warningTotal
        previewHardDeadline = Date().addingTimeInterval(warningTotal + 1)
        syncOverlay()
    }

    /// 仅供设计走查：把预警浮层固定在某个秒数上，便于检查最紧迫时的样子。
    func previewWarning(at seconds: TimeInterval) {
        previewKind = .warning
        previewRemaining = max(0, min(seconds, warningTotal))
        previewHardDeadline = nil
        syncOverlay()
    }

    /// 仅供设计走查 / 宣传图：模拟「已站满、等待用户确认」的样子。
    func previewFinished() {
        previewKind = .lock
        previewsFinished = true
        previewRemaining = 0
        previewHardDeadline = nil
        syncOverlay()
    }

    /// 仅供设计走查 / 宣传图：把锁屏浮层固定在某个剩余秒数上。
    func previewStand(at seconds: TimeInterval) {
        previewKind = .lock
        previewRemaining = max(0, min(seconds, standTotal))
        previewHardDeadline = nil
        syncOverlay()
    }

    func previewLock() {
        previewKind = .lock
        previewRemaining = standTotal
        // 试看别真把人锁 5 分钟，12 秒后自动放行。
        previewHardDeadline = Date().addingTimeInterval(12)
        syncOverlay()
    }

    func endPreview() {
        guard previewKind != nil else { return }
        previewKind = nil
        previewsFinished = false
        previewRemaining = 0
        previewHardDeadline = nil
        syncOverlay()
    }

    // MARK: - 内部推进

    private func startSitting(minutes: Double? = nil) {
        let duration = max(1, (minutes ?? settings.sitMinutes) * 60)
        phase = .sitting
        remaining = duration
        deadline = Date().addingTimeInterval(duration)
        SoundPlayer.shared.play(.release)
        syncOverlay()
    }

    private func startStanding() {
        let duration = max(1, settings.standMinutes * 60)
        phase = .standing
        remaining = duration
        deadline = Date().addingTimeInterval(duration)
        SoundPlayer.shared.play(.lock)
        syncOverlay()
    }

    private func resume() {
        if pausedPhase == .awaitingDismiss {
            phase = .awaitingDismiss
            deadline = nil
            remaining = 0
            syncOverlay()
            return
        }
        let duration = max(1, remaining)
        remaining = duration
        deadline = Date().addingTimeInterval(duration)
        phase = pausedPhase
        if phase == .sitting && duration <= settings.warningSeconds {
            phase = .warning
        }
        syncOverlay()
    }

    private func tick() {
        if previewKind != nil {
            previewRemaining -= 0.1
            let hardExpired = previewHardDeadline.map { Date() >= $0 } ?? false
            if previewRemaining <= 0 || hardExpired {
                previewRemaining = 0
                self.previewKind = nil
                previewHardDeadline = nil
            }
            syncOverlay()
            return
        }

        guard phase != .idle, let deadline else { return }
        let left = deadline.timeIntervalSinceNow

        if left <= 0 {
            remaining = 0
            advance()
            return
        }

        remaining = left
        if phase == .sitting && left <= settings.warningSeconds {
            phase = .warning
            SoundPlayer.shared.play(.warning)
            syncOverlay()
        }
    }

    private func advance() {
        switch phase {
        case .sitting, .warning:
            startStanding()
        case .standing:
            if settings.stayUntilDismissed {
                // 停在锁屏页，等用户点「开始下一轮」
                phase = .awaitingDismiss
                remaining = 0
                deadline = nil
                SoundPlayer.shared.play(.release)
                syncOverlay()
            } else {
                completedBreaks += 1
                startSitting()
            }
        case .awaitingDismiss, .idle:
            break
        }
    }

    /// 把 `phase` + `previewKind` 折叠成唯一一个浮层状态。
    private func syncOverlay() {
        let next: Overlay?
        if let previewKind {
            next = previewKind
        } else {
            switch phase {
            case .warning: next = .warning
            case .standing, .awaitingDismiss: next = .lock
            default: next = nil
            }
        }
        if overlay != next {
            overlay = next
        }
    }

    private func startTicking() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common 让计时器在菜单栏菜单弹出、窗口拖拽时也不中断
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - 设置变化响应

    private func sitDurationChanged(_ minutes: Double) {
        switch phase {
        case .sitting, .warning:
            startSitting(minutes: minutes)
        case .idle:
            if !automaticallyPaused { remaining = max(1, minutes * 60) }
        case .standing, .awaitingDismiss:
            break
        }
    }

    private func standDurationChanged(_ minutes: Double) {
        guard phase == .standing else { return }
        let duration = max(1, minutes * 60)
        remaining = duration
        deadline = Date().addingTimeInterval(duration)
    }

    // MARK: - 离开 / 回来

    private func handleAway() {
        guard settings.autoPauseWhenAway else { return }
        guard phase != .idle else { return }
        automaticallyPaused = true
        awayPaused = true
        pause()
    }

    private func handleReturn() {
        guard automaticallyPaused else { return }
        automaticallyPaused = false
        awayPaused = false
        if pausedPhase == .standing || pausedPhase == .awaitingDismiss {
            // 人已经离开过了，这次休息就算完成，别回来立刻锁屏。
            completedBreaks += 1
            startSitting()
        } else {
            resume()
        }
    }
}
