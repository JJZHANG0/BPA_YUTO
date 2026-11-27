import AVFoundation
import SwiftUI
import UIKit

struct TravelReadButton: View {
    let text: String
    @Environment(TravelStore.self) private var store
    @StateObject private var reader = TravelReader()

    var body: some View {
        if store.profile.readAloud ?? true {
            Button {
                if reader.speaking { reader.stop() } else { reader.read(text) }
            } label: {
                Label(reader.speaking ? "停止朗读" : "朗读", systemImage: reader.speaking ? "stop.circle" : "speaker.wave.2")
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .onDisappear { reader.stop() }
        }
    }
}

@MainActor
private final class TravelReader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func read(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.90
        speaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = self.synthesizer.isSpeaking }
    }
}

struct TravelContrastPreference: UIViewRepresentable {
    let increased: Bool

    func makeUIView(context: Context) -> Host { Host() }
    func updateUIView(_ view: Host, context: Context) {
        view.increased = increased
        view.apply()
    }

    final class Host: UIView {
        var increased = false
        override func didMoveToWindow() { super.didMoveToWindow(); apply() }

        func apply() {
            guard let window else { return }
            if increased {
                window.traitOverrides.accessibilityContrast = .high
            } else if window.traitOverrides.contains(UITraitAccessibilityContrast.self) {
                window.traitOverrides.remove(UITraitAccessibilityContrast.self)
            }
        }
    }
}
