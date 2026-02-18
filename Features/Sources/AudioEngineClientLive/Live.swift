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
                await actor.drumPads()
            },
            currentPresetID: {
                await actor.currentPresetID()
            },
            startRecording: {
                try await actor.startRecording()
            },
            stopRecording: {
                try await actor.stopRecording()
            },
            isRecording: {
                await actor.isRecording()
            },
            playRecordedAudio: {
                try await actor.playRecordedAudio()
            },
            positionUpdates: { padID in
                await actor.positionUpdates(for: padID)
            },
            currentTempo: {
                await actor.currentTempo()
            },
            preset: {
                await actor.preset()
            }
        )
    }()
}
