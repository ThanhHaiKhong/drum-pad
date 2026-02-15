import ComposableArchitecture
import AudioEngineClient
import AudioKit
import Foundation

extension AudioEngineClient: DependencyKey {
    public static let liveValue: AudioEngineClient = {
        let actor = AudioEngineActor()

        return AudioEngineClient(
            loadPreset: { presetID in
                try await actor.loadPreset(presetID)
            },
            playPad: { padID in
                try await actor.playPad(padID)
            },
            drumPads: {
                return await actor.drumPads()
            },
            currentPresetID: {
                return await actor.currentPresetID()
            },
            startRecording: {
                try await actor.startRecording()
            },
            stopRecording: {
                try await actor.stopRecording()
            },
            isRecording: {
                return await actor.isRecording()
            },
            playRecordedAudio: {
                try await actor.playRecordedAudio()
            },
            currentProgress: { padID in
                return 0.0
            }
        )
    }()
}
