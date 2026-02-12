import AudioEngineClient
import AudioKit
import Foundation

actor AudioEngineActor {
    private let delegate: AudioEngineDelegate

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
            print("🎵 [AUDIO_ENGINE_LIVE_ACTOR]: \(message)")
            #endif
        }
    ) {
        self.delegate = AudioEngineDelegate(logger: logger)
    }

    func loadPreset(presetId: String) async throws {
        try await delegate.loadPreset(presetId: presetId)
    }

    func playSample(at path: String) async throws {
        try await delegate.playSample(at: path)
    }

    func playPad(padId: Int) async throws {
        try await delegate.playPad(padId: padId)
    }

    func stopAll() async {
        await delegate.stopAll()
    }

    func loadedSamples() async -> [Int: AudioEngineClient.Sample] {
        return await delegate.loadedSamples()
    }

    func drumPads() async -> [Int: AudioEngineClient.DrumPad] {
        return await delegate.drumPads()
    }

    func isPresetLoaded() async -> Bool {
        return await delegate.isPresetLoaded()
    }

    func currentPresetId() async -> String? {
        return await delegate.currentPresetId()
    }

    func sampleDuration(at path: String) async throws -> Double {
        return try await delegate.sampleDuration(at: path)
    }

    func isRecording() async -> Bool {
        return await delegate.isRecording()
    }

    func startRecording() async throws {
        try await delegate.startRecording()
    }

    func stopRecording() async throws -> String? {
        return try await delegate.stopRecording()
    }

    func playRecordedAudio() async throws {
        try await delegate.playRecordedAudio()
    }
}
