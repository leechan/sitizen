import SwiftUI

/// 最后 N 秒的全屏透明预警。
///
/// 视觉思路：整块屏幕随倒计时一起「升温」。
/// —— 数字用 SF Rounded Black，靠体量而不是阴影撑住，滚动沿用 `numericText` 翻滚；
/// —— 字后面压一个巨型的同款幽灵数字，做出纪念碑式的层次；
/// —— 琥珀泛光、边缘光框、扩散脉冲环全部随剩余秒数增强；
/// —— 定长两位（10 → 09），宽度不变，翻滚时不会有任何位移。
struct WarningView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: SettingsStore

    @State private var breathing = false
    @State private var expanding = false
    @State private var line = ""

    private var total: TimeInterval { state.warningTotal }
    private var remaining: TimeInterval { min(max(0, state.displayRemaining), total) }
    private var seconds: Int { max(0, Int(remaining.rounded(.up))) }
    private var progress: Double { min(1, max(0, remaining / total)) }

    /// 紧迫度：0 = 刚进入预警，1 = 马上到点
    private var urgency: Double { 1 - progress }

    private var digits: String { String(format: "%02d", seconds) }
    private var accent: Color { Palette.accent }

    var body: some View {
        GeometryReader { geo in
            let k = min(1.0, max(0.55, geo.size.height / 900))
            let numeralSize = 268 * k
            let ruleWidth = min(geo.size.width * 0.50, 620 * k)

            ZStack {
                backdrop(scale: k)
                pulseRings(scale: k)

                VStack(spacing: 0) {
                    // 透明浮层上的小标签必须自带底，否则浅色壁纸上会糊掉
                    TrackedLabel(text: "即将起立", size: 12 * k, color: accent)
                        .padding(.horizontal, 14 * k)
                        .padding(.vertical, 7 * k)
                        .background(Capsule(style: .continuous).fill(Color.black.opacity(0.45)))
                        .overlay(Capsule(style: .continuous).stroke(accent.opacity(0.30), lineWidth: 1))
                        .padding(.bottom, 14 * k)

                    numeral(size: numeralSize, scale: k)

                    MicroProgress(progress: progress, width: ruleWidth, thickness: 3, tint: accent)
                        .padding(.top, 40 * k)

                    Text(line)
                        .font(.system(size: 16 * k, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.86))
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.top, 28 * k)
                        .shadow(color: Palette.scrim.opacity(0.85), radius: 4)
                        .id(line)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: line)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            if line.isEmpty {
                line = Copy.warning(settings.sass).randomElement() ?? ""
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathing = true
            }
            expanding = true
        }
    }

    // MARK: - 数字：体量 + 翻滚，不加硬阴影

    private func numeral(size: CGFloat, scale k: CGFloat) -> some View {
        RollingNumeral(text: digits, size: size, glowOpacity: 0.35 + 0.45 * urgency)
            .background(
                // 巨型幽灵数字，把数字撑成一块纪念碑
                Text(digits)
                    .font(.system(size: size * 2.15, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.045))
                    .fixedSize(horizontal: true, vertical: false)
                    .allowsHitTesting(false)
            )
            .scaleEffect(breathing ? 1.012 : 0.994, anchor: .center)
    }

    // MARK: - 气氛层

    /// 深色底衬（保证任何壁纸上都读得清）+ 随紧迫度升温的绿色泛光。
    private func backdrop(scale k: CGFloat) -> some View {
        ZStack {
            RadialGradient(
                colors: [Palette.scrim.opacity(0.80), Palette.scrim.opacity(0.46), .clear],
                center: .center,
                startRadius: 40 * k,
                endRadius: 640 * k
            )

            RadialGradient(
                colors: [
                    accent.opacity(0.10 + 0.34 * urgency),
                    accent.opacity(0.04 + 0.10 * urgency),
                    .clear
                ],
                center: .center,
                startRadius: 10 * k,
                endRadius: 560 * k
            )
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    /// 从中心向外扩散的三圈脉冲，越接近越亮。
    private func pulseRings(scale k: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(accent.opacity(expanding ? 0 : (0.20 + 0.30 * urgency)), lineWidth: 1.5)
                    .frame(width: 190 * k, height: 190 * k)
                    .scaleEffect(expanding ? 3.6 : 0.8)
                    .animation(
                        .easeOut(duration: 2.6)
                        .delay(Double(index) * 0.85)
                        .repeatForever(autoreverses: false),
                        value: expanding
                    )
            }
        }
        .allowsHitTesting(false)
    }
}
