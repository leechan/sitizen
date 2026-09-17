import Combine
import Foundation

enum SassLevel: String, CaseIterable, Identifiable {
    case mild
    case cheeky
    case savage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mild: return "温和"
        case .cheeky: return "调皮"
        case .savage: return "恶毒"
        }
    }

    var blurb: String {
        switch self {
        case .mild: return "轻声提醒，给你留点面子"
        case .cheeky: return "阴阳怪气，但还算有人性"
        case .savage: return "字字诛心，慎选"
        }
    }

    var glyph: String {
        switch self {
        case .mild: return "leaf.fill"
        case .cheeky: return "face.smiling.inverse"
        case .savage: return "flame.fill"
        }
    }
}

/// Single source of truth for user preferences. Backed by `UserDefaults`.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Key {
        static let sit = "sitMinutes"
        static let stand = "standMinutes"
        static let warning = "warningSeconds"
        static let sass = "sassLevel"
        static let sound = "soundEnabled"
        static let surrender = "allowSurrender"
        static let autoPause = "autoPauseWhenAway"
        static let launch = "launchAtLogin"
    }

    private let defaults: UserDefaults

    /// 久坐时长（分钟）
    @Published var sitMinutes: Double {
        didSet { persist() }
    }

    /// 起立时长（分钟）
    @Published var standMinutes: Double {
        didSet { persist() }
    }

    /// 预警提前量（秒）
    @Published var warningSeconds: Double {
        didSet { persist() }
    }

    /// 毒舌等级
    @Published var sass: SassLevel {
        didSet { persist() }
    }

    /// 音效
    @Published var soundEnabled: Bool {
        didSet { persist() }
    }

    /// 是否允许提前认输解锁
    @Published var allowSurrender: Bool {
        didSet { persist() }
    }

    /// 屏幕休眠 / 锁屏时自动暂停
    @Published var autoPauseWhenAway: Bool {
        didSet { persist() }
    }

    /// 开机启动
    @Published var launchAtLogin: Bool {
        didSet {
            persist()
            LaunchAtLogin.apply(launchAtLogin)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sitMinutes = defaults.object(forKey: Key.sit) as? Double ?? 45
        standMinutes = defaults.object(forKey: Key.stand) as? Double ?? 5
        warningSeconds = defaults.object(forKey: Key.warning) as? Double ?? 10
        sass = SassLevel(rawValue: defaults.string(forKey: Key.sass) ?? "") ?? .savage
        soundEnabled = defaults.object(forKey: Key.sound) as? Bool ?? true
        allowSurrender = defaults.object(forKey: Key.surrender) as? Bool ?? true
        autoPauseWhenAway = defaults.object(forKey: Key.autoPause) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Key.launch) as? Bool ?? false

        // 首次启动时同步一次真实状态，避免用户手动改过之后对不上。
        if defaults.object(forKey: Key.launch) == nil {
            LaunchAtLogin.apply(false)
        }
    }

    private func persist() {
        defaults.set(sitMinutes, forKey: Key.sit)
        defaults.set(standMinutes, forKey: Key.stand)
        defaults.set(warningSeconds, forKey: Key.warning)
        defaults.set(sass.rawValue, forKey: Key.sass)
        defaults.set(soundEnabled, forKey: Key.sound)
        defaults.set(allowSurrender, forKey: Key.surrender)
        defaults.set(autoPauseWhenAway, forKey: Key.autoPause)
        defaults.set(launchAtLogin, forKey: Key.launch)
    }
}
