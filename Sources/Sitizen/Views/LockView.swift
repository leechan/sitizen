import SwiftUI

/// 倒计时结束后的「锁屏」。
///
/// 全屏、拦截输入。视觉上是一次完整的品牌亮相：
/// 背景一片琥珀光 → 巨大的幽灵水印 → 大号极细数字 → 底部漂浮胶囊按钮。
struct LockView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: SettingsStore

    /// 只有主显示器的窗口有解锁按钮，其他屏幕显示提示。
    var isPrimary: Bool = true

    @State private var lineIndex = 0
    /// 点了「开始下一轮」或「认输」之后，浮层正在被拆掉。
    /// 这段时间里不能跟着 state 切到下一轮的界面，否则会闪一下旧按钮和下一轮的读数。
    @State private var leaving = false
    /// 离场那一刻的剩余秒数。冻结住，免得数字跟着下一轮跳一下。
    @State private var frozenRemaining: TimeInterval?
    @State private var confirming = false
    @State private var taunt = ""
    @State private var confirmResetWork: DispatchWorkItem?

    private let lineTimer = Timer.publish(every: 9, on: .main, in: .common).autoconnect()

    private var total: TimeInterval { state.standTotal }
    private var remaining: TimeInterval {
        if let frozenRemaining { return frozenRemaining }
        return min(max(0, state.displayRemaining), total)
    }
    private var progress: Double { min(1, max(0, remaining / total)) }
    private var seconds: Int { max(0, Int(remaining.rounded(.up))) }

    /// 站满待确认——包含「刚点完按钮、浮层还没消失」的那一小段。
    private var finished: Bool { state.isAwaitingDismiss || leaving }

    private var lines: [String] {
        finished ? Copy.finished(settings.sass) : Copy.lock(settings.sass)
    }

    private var currentLine: String {
        let pool = lines
        guard !pool.isEmpty else { return "" }
        return pool[lineIndex % pool.count]
    }

    var body: some View {
        GeometryReader { geo in
            let k = min(1.0, max(0.55, geo.size.height / 900))

            ZStack {
                AmbientBackdrop(intensity: isPrimary ? 1.0 : 0.7)

                GhostWordmark(text: "Sitizen", size: geo.size.width * 0.30)
                    .offset(y: -geo.size.height * 0.30)

                VStack(spacing: 0) {
                    Spacer(minLength: 10)

                    ButtMark()
                        .frame(
                            width: (isPrimary ? 232 : 168) * k,
                            height: (isPrimary ? 232 : 168) * k
                        )
                        .shadow(color: Palette.accent.opacity(0.35), radius: 40 * k)

                    TrackedLabel(
                        text: finished
                            ? "休息结束 · DONE"
                            : (isPrimary ? "休息中 · BREAK" : "休息中"),
                        size: 11 * k,
                        color: Palette.accent.opacity(0.9)
                    )
                    .padding(.top, 24 * k)

                    Text(finished ? "可以坐下了" : Copy.lockTitle)
                        .font(.display((isPrimary ? 60 : 44) * k, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 10 * k)

                    if isPrimary {
                        Text(currentLine)
                            .font(.system(size: 15 * k, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(Palette.dim)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 540)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14 * k)
                            .id(currentLine)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.4), value: currentLine)
                    }

                    clock(scale: k)
                        .padding(.top, (isPrimary ? 40 : 26) * k)

                    Spacer(minLength: 10)

                    footer(scale: k)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .onReceive(lineTimer) { _ in
            guard isPrimary, !confirming, !finished else { return }
            lineIndex += 1
        }
    }

    // MARK: - 剩余时间：两个大号数字块 + 小标签

    private func clock(scale k: CGFloat) -> some View {
        VStack(spacing: 20 * k) {
            HStack(alignment: .top, spacing: 34 * k) {
                NumeralBlock(
                    value: String(format: "%02d", seconds / 60),
                    label: "分",
                    numeralSize: (isPrimary ? 92 : 64) * k,
                    labelSize: 10 * k,
                    weight: .regular
                )
                NumeralBlock(
                    value: String(format: "%02d", seconds % 60),
                    label: "秒",
                    numeralSize: (isPrimary ? 92 : 64) * k,
                    labelSize: 10 * k,
                    weight: .regular
                )
            }

            MicroProgress(progress: progress, width: (isPrimary ? 300 : 220) * k)
        }
    }

    // MARK: - 底部

    @ViewBuilder
    private func footer(scale k: CGFloat) -> some View {
        VStack(spacing: 16 * k) {
            if !isPrimary {
                // 副屏只提示去哪儿操作，不给按钮
                TrackedLabel(text: "请到主显示器上解锁", size: 12 * k, color: Palette.dim, weight: .medium)
            } else if finished {
                // 站满了：只留一个「开始下一轮」，不再有认输选项
                FloatingPill {
                    PillButton(
                        title: Copy.dismissButton(settings.sass),
                        kind: .solid,
                        scale: k
                    ) {
                        beginLeaving()
                        state.dismissBreak()
                    }
                }

                Text("不点也行，它就一直待在这儿")
                    .font(.system(size: 11 * k, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Palette.faint)
            } else if settings.allowSurrender {
                if confirming {
                    Text(taunt)
                        .font(.system(size: 14 * k, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                FloatingPill {
                    PillButton(
                        title: confirming
                            ? Copy.surrenderConfirm(settings.sass)
                            : Copy.surrenderButton(settings.sass),
                        kind: confirming ? .solid : .ghost,
                        scale: k
                    ) {
                        primaryTapped()
                    }

                    if confirming {
                        Button {
                            resetConfirm()
                        } label: {
                            Text(Copy.surrenderCancel)
                                .font(.system(size: 14 * k, weight: .medium))
                                .foregroundStyle(Palette.dim)
                                .padding(.horizontal, 18 * k)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: confirming)

                Text("解锁后立刻开始下一轮久坐倒计时")
                    .font(.system(size: 11 * k, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Palette.faint)
            } else {
                TrackedLabel(text: "本次休息结束后自动解锁", size: 11 * k, color: Palette.dim, weight: .medium)

                Text("解锁后立刻开始下一轮久坐倒计时")
                    .font(.system(size: 11 * k, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Palette.faint)
            }
        }
        .padding(.bottom, 44 * k)
    }

    // MARK: - 认输两步确认

    private func primaryTapped() {
        if confirming {
            // 直接认输退出。不要重置 confirming，也不要让界面切回去，
            // 否则浮层消失前会先闪一下初始态。
            confirmResetWork?.cancel()
            beginLeaving()
            state.surrender()
            return
        }

        SoundPlayer.shared.play(.click)
        let pool = Copy.surrenderTaunt(settings.sass)
        taunt = pool.randomElement().map { Copy.renderDuration($0, remaining: remaining) } ?? ""
        confirming = true

        let work = DispatchWorkItem { confirming = false }
        confirmResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: work)
    }

    /// 进入「即将离场」：界面整体冻结在当前这一帧，直到浮层被拆掉。
    private func beginLeaving() {
        frozenRemaining = remaining
        leaving = true
    }

    private func resetConfirm() {
        confirmResetWork?.cancel()
        confirming = false
        SoundPlayer.shared.play(.click)
    }
}
