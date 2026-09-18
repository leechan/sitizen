import SwiftUI

/// 设置窗口专用的浅色纸张主题。
/// 刻意不动 `Palette` —— 其它界面（预警、锁屏、菜单栏、图标）保持深色墨绿不变。
enum PaperPalette {
    /// 淡黄纸张
    static let paper = Color(hex: 0xF6F2E4)
    static let paperDeep = Color(hex: 0xEFE9D6)
    /// 抬起的卡片面
    static let card = Color(hex: 0xFCFAF1)

    /// 浅绿
    static let sage = Color(hex: 0x76AE7F)
    static let sageLight = Color(hex: 0x9ACBA4)
    static let sageDeep = Color(hex: 0x4E8359)

    /// 橄榄金
    static let olive = Color(hex: 0xC6AE3A)

    /// 文字
    static let ink = Color(hex: 0x1C2520)
    static let inkDim = Color(hex: 0x1C2520).opacity(0.56)
    static let inkFaint = Color(hex: 0x1C2520).opacity(0.34)
    static let hairline = Color(hex: 0x1C2520).opacity(0.10)
    static let wash = Color(hex: 0x1C2520).opacity(0.05)

    static let sageGradient = LinearGradient(
        colors: [sageLight, sage],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 设置页背景：淡黄纸张 + 左上角一片浅绿 + 右下角一点橄榄。
struct SettingsBackground: View {
    var body: some View {
        GeometryReader { geo in
            let span = max(geo.size.width, geo.size.height)
            ZStack {
                PaperPalette.paper

                RadialGradient(
                    colors: [PaperPalette.sage.opacity(0.26), .clear],
                    center: UnitPoint(x: 0.10, y: 0.0),
                    startRadius: 0,
                    endRadius: span * 0.62
                )

                RadialGradient(
                    colors: [PaperPalette.olive.opacity(0.13), .clear],
                    center: UnitPoint(x: 1.0, y: 1.0),
                    startRadius: 0,
                    endRadius: span * 0.55
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var state: AppState

    var onPreviewWarning: () -> Void
    var onPreviewLock: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ScrollView {
            SettingsContent(
                settings: settings,
                state: state,
                onPreviewWarning: onPreviewWarning,
                onPreviewLock: onPreviewLock,
                onQuit: onQuit
            )
        }
        .background(SettingsBackground())
        .frame(minWidth: 460, minHeight: 620)
    }
}

struct SettingsContent: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var state: AppState

    var onPreviewWarning: () -> Void
    var onPreviewLock: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            rhythm
            personality
            behavior
            preview
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - 头部

    private var header: some View {
        SettingsHeader()
    }

    // MARK: - 节奏

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(zh: "节奏", en: "TEMPO")

            DurationRow(
                label: "久坐时长",
                value: $settings.sitMinutes,
                range: 1...180,
                step: 5,
                unit: "分钟"
            )
            DurationRow(
                label: "起立时长",
                value: $settings.standMinutes,
                range: 1...60,
                step: 1,
                unit: "分钟"
            )
            DurationRow(
                label: "提前预警",
                value: $settings.warningSeconds,
                range: 3...30,
                step: 1,
                unit: "秒"
            )
        }
    }

    // MARK: - 性格

    private var personality: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(zh: "性格", en: "TONE")

            HStack(spacing: 8) {
                ForEach(SassLevel.allCases) { level in
                    ToneOption(level: level, selected: settings.sass == level) {
                        settings.sass = level
                        SoundPlayer.shared.play(.click)
                    }
                }
            }

            Text(settings.sass.blurb)
                .font(.system(size: 12, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(PaperPalette.inkDim)
        }
    }

    // MARK: - 行为

    private var behavior: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(zh: "行为", en: "BEHAVIOR")

            VStack(spacing: 0) {
                ToggleRow(title: "音效", subtitle: "预警、锁屏、解锁时各来一声", isOn: $settings.soundEnabled)
                Hairline(color: PaperPalette.hairline)
                ToggleRow(title: "允许认输解锁", subtitle: "关掉之后，休息时间就只能站满", isOn: $settings.allowSurrender)
                Hairline(color: PaperPalette.hairline)
                ToggleRow(
                    title: "休息结束后停留",
                    subtitle: "站满后停在锁屏页，点一下才开始下一轮",
                    isOn: $settings.stayUntilDismissed
                )
                Hairline(color: PaperPalette.hairline)
                ToggleRow(title: "休眠 / 锁屏时自动暂停", subtitle: "人都不在了，就不算久坐", isOn: $settings.autoPauseWhenAway)
                Hairline(color: PaperPalette.hairline)
                ToggleRow(
                    title: "开机自动启动",
                    subtitle: AppInfo.isBundled ? "打包运行后生效" : "开发模式下不可用",
                    isOn: $settings.launchAtLogin
                )
            }
        }
    }

    // MARK: - 试看

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(zh: "试看", en: "PREVIEW")

            HStack(spacing: 12) {
                GhostButton(title: "预警效果", action: onPreviewWarning)
                GhostButton(title: "锁屏效果", action: onPreviewLock)
            }

            Text("试看不会影响正在进行的计时。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PaperPalette.inkFaint)
        }
    }

    private var footer: some View {
        HStack {
            Text("本轮已起身 \(state.completedBreaks) 次")
                .font(.system(size: 12, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(PaperPalette.inkFaint)
            Spacer()
            Button(action: onQuit) {
                Text("退出 Sitizen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PaperPalette.sageDeep)
            }
            .buttonStyle(.plain)
        }
    }
}

/// 设置页顶部：吉祥物 + 字标 + 一行说明。
struct SettingsHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // 浅纸底上给图标一块深色小方砖
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(hex: 0x2E4437))
                    .frame(width: 48, height: 48)
                ButtMark(tilt: 0)
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 5) {
                Wordmark()
                TrackedLabel(text: AppInfo.tagline, size: 10, color: PaperPalette.inkDim, weight: .medium)
            }

            Spacer()

            TrackedLabel(text: "V\(AppInfo.version)", size: 10, color: PaperPalette.inkFaint, weight: .medium)
        }
    }
}

// MARK: - 品牌字

/// 设置页顶部的 Sitizen 字标。浅纸底上用 深绿 → 浅绿 → 橄榄 的斜向渐变。
struct Wordmark: View {
    var body: some View {
        Text("SITIZEN")
            .font(.system(size: 29, weight: .heavy))
            .tracking(2.2)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: 0x27503A), PaperPalette.sageDeep, PaperPalette.sage],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color(hex: 0x27503A).opacity(0.18), radius: 6, y: 2)
    }
}

// MARK: - 复用组件

struct SectionTitle: View {
    var zh: String
    var en: String

    var body: some View {
        HStack(spacing: 10) {
            Text(zh)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PaperPalette.ink)
            TrackedLabel(text: en, size: 10, color: PaperPalette.sageDeep.opacity(0.85), weight: .semibold)
            Hairline(color: PaperPalette.hairline)
        }
    }
}

/// 时长选择：−/+ 精准微调 + 一根够粗、够好拖的滑杆。
struct DurationRow: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var unit: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(PaperPalette.ink.opacity(0.85))

                Spacer()

                StepButton(systemName: "minus") { adjust(-step) }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(value))")
                        .font(.numeral(23, weight: .medium))
                        .foregroundStyle(PaperPalette.olive)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: value)
                    TrackedLabel(text: unit, size: 9, color: PaperPalette.inkFaint, weight: .medium)
                }
                .frame(minWidth: 70)

                StepButton(systemName: "plus") { adjust(step) }
            }

            ThickSlider(value: $value, range: range, step: step)
        }
    }

    private func adjust(_ delta: Double) {
        value = min(range.upperBound, max(range.lowerBound, value + delta))
        SoundPlayer.shared.play(.click)
    }
}

/// 够粗、够好拖的滑杆。轨道 8pt，手柄 22pt，整行 34pt 都是热区。
struct ThickSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double

    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let knobX = min(width - 11, max(11, width * fraction))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PaperPalette.ink.opacity(0.10))
                    .frame(height: 8)

                Capsule()
                    .fill(PaperPalette.sageGradient)
                    .frame(width: knobX, height: 8)

                Circle()
                    .fill(PaperPalette.card)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(
                            PaperPalette.sage.opacity(dragging ? 1 : 0.65),
                            lineWidth: 2.5
                        )
                    )
                    .shadow(color: PaperPalette.ink.opacity(dragging ? 0.28 : 0.16), radius: 5, y: 2)
                    .scaleEffect(dragging ? 1.14 : 1)
                    .offset(x: knobX - 11)
            }
            .frame(height: 34)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        dragging = true
                        let raw = min(1, max(0, gesture.location.x / width))
                        let target = range.lowerBound + Double(raw) * (range.upperBound - range.lowerBound)
                        value = min(range.upperBound, max(range.lowerBound, (target / step).rounded() * step))
                    }
                    .onEnded { _ in
                        dragging = false
                        SoundPlayer.shared.play(.click)
                    }
            )
        }
        .frame(height: 34)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
    }
}

struct StepButton: View {
    var systemName: String
    var action: () -> Void

    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(hovering ? PaperPalette.card : PaperPalette.ink.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(
                        hovering
                            ? AnyShapeStyle(PaperPalette.sageGradient)
                            : AnyShapeStyle(PaperPalette.wash)
                    )
                )
                .overlay(
                    Circle().stroke(PaperPalette.ink.opacity(0.08), lineWidth: 1)
                )
                .scaleEffect(pressed ? 0.9 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

/// 行为设置行：文案靠左、开关贴到最右边，两端对齐。
struct ToggleRow: View {
    var title: String
    var subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PaperPalette.ink.opacity(0.9))
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(PaperPalette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            PaperSwitch(isOn: $isOn)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
    }
}

/// 纸张风格的开关。不用原生 `Toggle`：一来更贴合浅色纸张主题，
/// 二来离屏渲染（宣传图）里原生开关只会画成一个占位方块。
struct PaperSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                isOn.toggle()
            }
            SoundPlayer.shared.play(.click)
        } label: {
            Capsule(style: .continuous)
                .fill(
                    isOn
                        ? AnyShapeStyle(PaperPalette.sageGradient)
                        : AnyShapeStyle(PaperPalette.ink.opacity(0.16))
                )
                .frame(width: 46, height: 27)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(PaperPalette.ink.opacity(isOn ? 0 : 0.10), lineWidth: 1)
                )
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 21, height: 21)
                        .shadow(color: PaperPalette.ink.opacity(0.22), radius: 2, y: 1)
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

struct ToneOption: View {
    var level: SassLevel
    var selected: Bool
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: level.glyph)
                    .font(.system(size: 16, weight: .semibold))
                Text(level.label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(2)
            }
            .foregroundStyle(selected ? PaperPalette.ink : PaperPalette.ink.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        selected
                            ? AnyShapeStyle(PaperPalette.sageGradient)
                            : AnyShapeStyle(hovering ? PaperPalette.ink.opacity(0.09) : PaperPalette.wash)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(PaperPalette.ink.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.16), value: hovering)
    }
}

struct GhostButton: View {
    var title: String
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundStyle(hovering ? PaperPalette.sageDeep : PaperPalette.ink.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(hovering ? PaperPalette.sage.opacity(0.18) : PaperPalette.wash)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(PaperPalette.ink.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.16), value: hovering)
    }
}
