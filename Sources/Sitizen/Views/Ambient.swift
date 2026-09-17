import SwiftUI

/// 大间距的小标签，参考图里 "Spa" / "Days" / "Hours" 那种。
struct TrackedLabel: View {
    var text: String
    var size: CGFloat = 11
    var color: Color = Palette.accent
    var weight: Font.Weight = .semibold

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .tracking(size * 0.26)
            .foregroundStyle(color)
    }
}

/// 一条发丝级的分隔线。
struct Hairline: View {
    var color: Color = Palette.hairline
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// 细进度条：轨道几乎不可见，进度是强调色。
struct MicroProgress: View {
    var progress: Double
    var width: CGFloat
    var thickness: CGFloat = 2
    var tint: Color = Palette.accent

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: width, height: thickness)
            Capsule()
                .fill(tint)
                .frame(width: max(0, width * min(1, max(0, progress))), height: thickness)
                .shadow(color: tint.opacity(0.8), radius: 8)
        }
        .frame(width: width, height: thickness)
    }
}

/// 大号数字 + 下面一行小标签，参考图的 "00 / Days"。
struct NumeralBlock: View {
    var value: String
    var label: String
    var numeralSize: CGFloat
    var labelSize: CGFloat
    var weight: Font.Weight = .thin
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.numeral(numeralSize, weight: weight))
                .foregroundStyle(tint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            TrackedLabel(text: label, size: labelSize, color: Palette.dim, weight: .medium)
        }
    }
}

/// 背景：纯黑 + 顶部一大片强调色渐隐 + 压暗。参考图的核心氛围。
struct AmbientBackdrop: View {
    var intensity: Double = 1.0
    var tint: Color = Palette.accent

    var body: some View {
        GeometryReader { geo in
            let span = max(geo.size.width, geo.size.height)

            ZStack {
                Palette.ink

                RadialGradient(
                    colors: [
                        tint.opacity(0.52 * intensity),
                        tint.opacity(0.16 * intensity),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.16),
                    startRadius: 0,
                    endRadius: span * 0.78
                )

                // 底部压回纯黑，让文字区域永远够暗
                LinearGradient(
                    colors: [.clear, Palette.ink.opacity(0.9), Palette.ink],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// 预警用的大号数字。
///
/// 体量靠 Rounded Black 字重撑，而不是靠阴影堆；
/// 切换时用 `numericText` 翻滚。
/// 调用方必须传**定长**字符串（例如 `%02d`），配合 monospacedDigit 保证宽度恒定，
/// 这样 10 → 09 翻滚时不会有任何位移。
struct RollingNumeral: View {
    var text: String
    var size: CGFloat
    var glowOpacity: Double = 0.4

    private var font: Font {
        .system(size: size, weight: .black, design: .rounded).monospacedDigit()
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .white,
                        Color(hex: 0xD3E8D7),
                        Palette.accent
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy(duration: 0.38), value: text)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .shadow(color: Palette.accent.opacity(glowOpacity), radius: size * 0.10)
    }
}

/// 极淡的斜纹，给大面积渐变加一点材质。单次绘制，开销可忽略。
struct HairlineOverlay: View {
    var spacing: CGFloat = 7
    var opacity: Double = 0.05

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let span = geo.size.width + geo.size.height
                var offset: CGFloat = -geo.size.height
                while offset < span {
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset + geo.size.height, y: geo.size.height))
                    offset += spacing
                }
            }
            .stroke(Color.white.opacity(opacity), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// 压得很低的大字，放在背景里当水印，参考图那个 "belgiu"。
struct GhostWordmark: View {
    var text: String
    var size: CGFloat
    var color: Color = .white
    var opacity: Double = 0.055

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .tracking(-size * 0.04)
            .foregroundStyle(color.opacity(opacity))
            .lineLimit(1)
            .fixedSize()
            .allowsHitTesting(false)
    }
}

/// 漂浮的胶囊容器，放按钮用。
struct FloatingPill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }
}

/// 胶囊按钮，强调色实心或幽灵两种。
struct PillButton: View {
    enum Kind {
        case solid
        case ghost
    }

    var title: String
    var kind: Kind = .solid
    var scale: CGFloat = 1
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16 * scale, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(kind == .solid ? Palette.ink : Color.white.opacity(0.85))
                .padding(.horizontal, 30 * scale)
                .padding(.vertical, 14 * scale)
                .frame(minWidth: 190 * scale)
                .background(
                    Capsule(style: .continuous)
                        .fill(kind == .solid ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.white.opacity(hovering ? 0.16 : 0.07)))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(kind == .solid ? 0.0 : 0.14), lineWidth: 1)
                )
                .scaleEffect(hovering ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hovering)
    }
}
