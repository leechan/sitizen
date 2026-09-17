import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1
        )
    }
}

/// Sitizen 的视觉系统。
///
/// 色板从「黑 + 琥珀」换成「深墨绿 + 鼠尾草绿 + 橄榄金」，
/// 整体压低明度，不再刺眼。
enum Palette {
    /// 底色：#1c2520 深墨绿
    static let ink = Color(hex: 0x1C2520)
    /// 抬升面 / 描边：#27362c
    static let surface = Color(hex: 0x27362C)

    /// 主强调：#76ae7f 鼠尾草绿
    static let accent = Color(hex: 0x76AE7F)
    /// 主强调的深色端
    static let accentDeep = Color(hex: 0x3E6B4A)

    /// 次强调：#ac9d44 橄榄金
    static let olive = Color(hex: 0xAC9D44)
    static let oliveLight = Color(hex: 0xC7B95E)
    static let oliveDeep = Color(hex: 0x7E7228)

    /// 亮文字
    static let bone = Color(hex: 0xEDF2EC)

    static let dim = Color(hex: 0xEDF2EC).opacity(0.58)
    static let faint = Color(hex: 0xEDF2EC).opacity(0.32)
    static let hairline = Color(hex: 0x76AE7F).opacity(0.18)

    /// 透明浮层的底衬，用深墨绿而不是纯黑，和整体色调一致
    static let scrim = Color(hex: 0x0B120E)

    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let oliveGradient = LinearGradient(
        colors: [oliveLight, olive, oliveDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Font {
    /// 参考图里那种超大、极细、等宽的数字。
    static func numeral(_ size: CGFloat, weight: Font.Weight = .thin) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }
}
