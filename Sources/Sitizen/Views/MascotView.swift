import SwiftUI

/// Sitizen 的吉祥物：一把会对你失望的小凳子。
///
/// 简化到只有「靠背 + 坐面 + 两条腿」，颜色用琥珀色系而不是惨白，
/// 五官压在近黑上，黑白金三色就够。
struct MascotView: View {
    enum Mood {
        case smug      // 预警中，坏笑
        case shout     // 锁屏中，咆哮
        case mocking   // 认输确认，嘲讽
    }

    var mood: Mood
    var size: CGFloat = 220
    /// 菜单栏 / 图标这类小尺寸下关掉外发光和阴影，否则会糊成一团。
    var flat: Bool = false

    @State private var blink = false
    @State private var bouncing = false

    private let blinkTimer = Timer.publish(every: 3.4, on: .main, in: .common).autoconnect()

    /// 靠背：橄榄金，色板里的 #ac9d44 系
    private var shell: LinearGradient {
        Palette.oliveGradient
    }

    /// 腿和坐面：再深一档，做出结构感
    private var frame: LinearGradient {
        LinearGradient(
            colors: [Palette.olive, Palette.oliveDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            legs
            seat
            backPanel
        }
        .frame(width: 220, height: 260)
        .scaleEffect(size / 220)
        .frame(width: size, height: size * 260 / 220)
        .offset(y: bouncing ? -8 : 0)
        .onAppear {
            guard mood == .shout else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                bouncing = true
            }
        }
        .onReceive(blinkTimer) { _ in
            blink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                blink = false
            }
        }
    }

    // MARK: - 部件

    private var legs: some View {
        HStack(spacing: 88) {
            leg
            leg
        }
        .offset(y: 128)
    }

    private var leg: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(frame)
            .frame(width: 16, height: 44)
    }

    private var seat: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(frame)
            .frame(width: 200, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.bone.opacity(0.18), lineWidth: 1)
            )
            .offset(y: 96)
    }

    private var backPanel: some View {
        RoundedRectangle(cornerRadius: 46, style: .continuous)
            .fill(shell)
            .overlay(
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .stroke(Palette.bone.opacity(0.22), lineWidth: 1.5)
            )
            .overlay(face)
            .frame(width: 178, height: 184)
            .shadow(color: flat ? .clear : Palette.oliveDeep.opacity(0.45), radius: 30, y: 14)
            .offset(y: -10)
    }

    private var face: some View {
        ZStack {
            HStack(spacing: 34) {
                eye
                eye
            }

            HStack(spacing: 36) {
                brow(angle: -browAngle)
                brow(angle: browAngle)
            }
            .offset(y: -48)

            mouth
                .offset(y: 44)

            blush
        }
    }

    private var eye: some View {
        ZStack {
            Circle()
                .fill(Palette.ink)
                .frame(width: 40, height: 40)
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 11, height: 11)
                .offset(x: pupilOffset - 2, y: -5)
        }
        .scaleEffect(x: 1, y: blink ? 0.1 : 1, anchor: .center)
        .animation(.easeInOut(duration: 0.08), value: blink)
    }

    private func brow(angle: Double) -> some View {
        Capsule(style: .continuous)
            .fill(Palette.ink)
            .frame(width: 38, height: 8)
            .rotationEffect(.degrees(angle))
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .smug:
            SmileShape(depth: 0.75)
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 54, height: 22)

        case .shout:
            Ellipse()
                .fill(Palette.ink)
                .frame(width: 52, height: 60)
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(Palette.accent)
                        .frame(width: 28, height: 20)
                        .padding(.bottom, 6)
                }
                .clipShape(Ellipse())

        case .mocking:
            ZStack(alignment: .top) {
                SmileShape(depth: 1.05)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 68, height: 26)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.ink.opacity(0.85))
                    .frame(width: 32, height: 9)
                    .offset(y: 10)
            }
        }
    }

    private var blush: some View {
        HStack(spacing: 92) {
            Circle().fill(Palette.accent.opacity(0.45)).frame(width: 26, height: 16)
            Circle().fill(Palette.accent.opacity(0.45)).frame(width: 26, height: 16)
        }
        .offset(y: 18)
        .blur(radius: 3)
    }

    private var browAngle: Double {
        switch mood {
        case .smug: return 9
        case .shout: return 24
        case .mocking: return 14
        }
    }

    private var pupilOffset: CGFloat {
        switch mood {
        case .smug: return 4
        case .shout: return 0
        case .mocking: return -4
        }
    }
}

struct SmileShape: Shape {
    var depth: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 2 * depth)
        )
        return path
    }
}
