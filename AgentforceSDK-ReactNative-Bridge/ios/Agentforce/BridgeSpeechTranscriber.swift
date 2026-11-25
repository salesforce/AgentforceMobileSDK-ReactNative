/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Speech transcriber implementing AgentforceSpeechTranscriber.
 * Captures microphone audio and passes it to React Native via callbacks.
 */

import Foundation
import AVFoundation
import AgentforceSDK

final class BridgeSpeechTranscriber: NSObject, AgentforceSpeechTranscriber, AVAudioRecorderDelegate {

    enum TranscribingPhase: String {
        case idle
        case recording
        case awaitingTranscript
        case finishing
    }

    weak var delegate: AgentforceSpeechTranscriberDelegate?
    weak var module: AgentforceModule?

    private var audioRecorder: AVAudioRecorder?
    private(set) var phase: TranscribingPhase = .idle
    private(set) var currentRequestId: String?
    private(set) var currentAudioFileURL: URL?

    @MainActor
    func startTranscribing(completion: @escaping (Error?) -> Void) {
        if phase == .recording || audioRecorder?.isRecording == true {
            stopAudioRecording()
        }

        requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard granted else {
                    let error = NSError(
                        domain: "BridgeSpeechTranscriber",
                        code: 1002,
                        userInfo: [NSLocalizedDescriptionKey: "Microphone permission is denied. Please enable it in Settings."]
                    )
                    completion(error)
                    return
                }

                guard let self = self else { return }

                do {
                    let requestId = UUID().uuidString
                    self.currentRequestId = requestId
                    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("agentforce_speech_\(requestId).m4a")
                    self.currentAudioFileURL = fileURL

                    try self.beginAudioRecording(to: fileURL)
                    self.phase = .recording
                    self.delegate?.transcript = ""
                    self.delegate?.isTranscribing = true

                    self.module?.emitSpeechRecordingStarted()
                    completion(nil)
                } catch {
                    self.stopAudioRecording()
                    self.phase = .idle
                    self.currentRequestId = nil
                    completion(error)
                }
            }
        }
    }

    @MainActor
    func stopTranscribing() {
        // Make repeated stopTranscribing() a no-op during awaitingTranscript
        if phase == .awaitingTranscript {
            return
        }

        guard phase == .recording else {
            delegate?.isTranscribing = false
            phase = .idle
            return
        }

        stopAudioRecording()
        deactivateAudioSession()

        phase = .awaitingTranscript
        // Keep isTranscribing = true during valid pending transcription

        if let fileURL = self.currentAudioFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            let requestId = currentRequestId ?? ""
            module?.emitSpeechAudioRecorded([
                "audioUri": fileURL.absoluteString,
                "filePath": fileURL.path,
                "requestId": requestId
            ])
        } else {
            delegate?.isTranscribing = false
            phase = .idle
            currentRequestId = nil
        }
    }

    @MainActor
    @discardableResult
    func setTranscript(_ text: String, requestId: String? = nil) -> Bool {
        guard let activeDelegate = delegate else {
            return false
        }

        if let incomingId = requestId, let curId = currentRequestId, incomingId != curId {
            return false
        }

        phase = .finishing

        // Deliver result while isTranscribing remains true so SwiftUI .onChange passes its guard
        activeDelegate.transcript = text

        // Allow SwiftUI's view observer on MainActor to consume newTranscript before ending dictation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak activeDelegate] in
            guard let self = self else { return }
            activeDelegate?.isTranscribing = false
            self.phase = .idle
            self.currentRequestId = nil
            self.cleanupAudioFile()
        }

        return true
    }

    @MainActor
    private func beginAudioRecording(to fileURL: URL) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        try? FileManager.default.removeItem(at: fileURL)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        guard audioRecorder?.record() == true else {
            throw NSError(
                domain: "BridgeSpeechTranscriber",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start audio recording."]
            )
        }
    }

    @MainActor
    private func stopAudioRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanupAudioFile() {
        if let url = currentAudioFileURL {
            try? FileManager.default.removeItem(at: url)
            currentAudioFileURL = nil
        }
    }

    private func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        } else {
            session.requestRecordPermission { granted in
                completion(granted)
            }
        }
    }
}
