import SwiftUI

/// App 图标上的「翘臀」标记。
///
/// 两个等大的圆叠出一个饱满的两瓣剪影，底部一条上尖下宽的软缝。
/// 刻意做得非常图形化，不写实、不含任何解剖细节。
struct ButtMark: View {
    /// 整体上翘的角度
    var tilt: Double = -6

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)

            let lobeSize = s * 0.58
            let lobeSpread = s * 0.118

            // 两瓣同色叠加，重叠够大所以顶部是平滑的圆弧
            let silhouette = ZStack {
                Circle().frame(width: lobeSize, height: lobeSize).offset(x: -lobeSpread)
                Circle().frame(width: lobeSize, height: lobeSize).offset(x: lobeSpread)
            }
            .frame(width: s, height: s)

            // 底部那条缝：上尖下宽、两侧内凹，比等宽胶囊自然得多
            let cleft = CleftShape()
                .frame(width: s * 0.105, height: s * 0.26)
                .offset(y: s * 0.19)

            let mask = silhouette
                .foregroundStyle(.white)
                .overlay(cleft.blendMode(.destinationOut))
                .compositingGroup()

            silhouette
                .foregroundStyle(Color(hex: 0xF4EBDC))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xFEFAF2),
                            Color(hex: 0xF2E6CF),
                            Color(hex: 0xD6C19C)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                // 两瓣上的柔光，圆润感全靠它
                .overlay(
                    ZStack {
                        ForEach([-1.0, 1.0], id: \.self) { side in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white.opacity(0.78), .white.opacity(0)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: s * 0.145
                                    )
                                )
                                .frame(width: s * 0.30, height: s * 0.30)
                                .offset(
                                    x: CGFloat(side) * (lobeSpread + s * 0.035),
                                    y: -s * 0.055
                                )
                        }
                    }
                )
                .mask(mask)
                .rotationEffect(.degrees(tilt))
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// 底部那条缝。上端收成软尖，往下微微张开，两侧内凹。
private struct CleftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX + rect.width * 0.20, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.midX - rect.width * 0.20, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}
