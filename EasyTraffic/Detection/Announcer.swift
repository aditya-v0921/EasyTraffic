//
//  Announcer.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 10/16/25.
//

import AVFoundation

final class Announcer: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Announcer()
    private let synth = AVSpeechSynthesizer()
    private var lastSpokenAt: Date = .distantPast
    var minSpeakInterval: TimeInterval = 8.0

    private override init() {
        super.init()
        synth.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Simpler: just playback with ducking
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            print("Audio session configured successfully")
        } catch {
            print("Audio session error:", error)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Speech started:", utterance.speechString)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Speech finished:", utterance.speechString)
    }

    func say(_ text: String) {
        guard Date().timeIntervalSince(lastSpokenAt) > minSpeakInterval else { return }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(u)
        lastSpokenAt = Date()
        print("Speaking:", text)
    }
}
