import AppKit
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()

    /// 自检 / 离屏渲染时静音。
    static var isMuted = false

    enum Cue {
        case warning
        case lock
        case release
        case click
        case surrender
    }

    private init() {}

    func play(_ cue: Cue) {
        guard !SoundPlayer.isMuted, SettingsStore.shared.soundEnabled else { return }
        let name: String
        switch cue {
        case .warning: name = "Tink"
        case .lock: name = "Basso"
        case .release: name = "Glass"
        case .click: name = "Pop"
        case .surrender: name = "Funk"
        }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
