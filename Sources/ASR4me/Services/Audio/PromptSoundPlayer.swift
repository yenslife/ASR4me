import AppKit
import Foundation

protocol PromptSoundPlaying: Sendable {
    func playStartSound()
    func playStopSound()
}

struct PromptSoundPlayer: PromptSoundPlaying {
    func playStartSound() {
        play(named: "Glass")
    }

    func playStopSound() {
        play(named: "Tink")
    }

    private func play(named: String) {
        DispatchQueue.main.async {
            NSSound(named: NSSound.Name(named))?.play()
        }
    }
}

