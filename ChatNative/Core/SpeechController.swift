import Foundation
import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var level: Float = 0
    @Published var transcript = ""
    @Published var error: String?
    private let engine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var permissionID = UUID()
    private var recognitionID = UUID()
    private var update: ((String) -> Void)?

    override init() { super.init(); synthesizer.delegate = self }

    func startListening(language: String, onText: @escaping (String) -> Void) {
        stopSpeaking()
        stopListening()
        error = nil
        transcript = ""
        update = onText
        let token = UUID()
        permissionID = token
        Task { @MainActor in
            let authorized = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
            let microphone = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard permissionID == token else { return }
            guard authorized && microphone else { error = "请在 iOS 设置中允许麦克风与语音识别权限。"; return }
            beginRecognition(language: language)
        }
    }
    private func beginRecognition(language: String) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable else {
            error = "系统语音识别当前不可用，请稍后重试。"; return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else { throw APIError.server("找不到可用的麦克风。") }
            let token = UUID()
            recognitionID = token
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                guard let channel = buffer.floatChannelData?[0] else { return }
                let count = Int(buffer.frameLength)
                guard count > 0 else { return }
                var sum: Float = 0
                for i in 0..<count { sum += channel[i] * channel[i] }
                let amplitude = min(1, sqrt(sum / Float(count)) * 8)
                Task { @MainActor [weak self] in if self?.recognitionID == token { self?.level = amplitude } }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            isListening = true
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, failure in
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionID == token else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        self.update?(self.transcript)
                        if result.isFinal { self.stopListening() }
                    }
                    if let failure, self.isListening { self.error = failure.localizedDescription; self.stopListening() }
                }
            }
        } catch { self.error = error.localizedDescription; stopListening() }
    }
    func stopListening() {
        permissionID = UUID()
        recognitionID = UUID()
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio()
        recognition?.cancel()
        recognition = nil
        request = nil
        update = nil
        isListening = false
        level = 0
        if !isSpeaking { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
    func speak(_ text: String, language: String) {
        guard !text.isEmpty else { return }
        stopListening()
        stopSpeaking()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            isSpeaking = true
            synthesizer.speak(utterance)
        } catch { self.error = error.localizedDescription }
    }
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, !self.synthesizer.isSpeaking else { return }
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
