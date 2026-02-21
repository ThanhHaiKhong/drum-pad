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

    func loadPreset(_ presetID: String) async throws {
        try await delegate.loadPreset(presetID)
    }

    func playPad(_ padID: AudioEngineClient.DrumPad.ID) async throws {
        try await delegate.playPad(padID)
    }

    func drumPads() async -> [AudioEngineClient.DrumPad] {
        return await delegate.drumPads()
    }

    func currentPresetID() async -> String? {
        return await delegate.currentPresetID()
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
    
    func positionUpdates(for padID: AudioEngineClient.DrumPad.ID) -> AsyncStream<AudioEngineClient.PositionUpdate> {
        return delegate.positionUpdates(for: padID)
    }
    
    // MARK: - Preset Metadata

    func currentTempo() async -> Int {
        return await delegate.currentTempo()
    }

    func preset() async -> AudioEngineClient.Preset? {
        return await delegate.preset()
    }
}
