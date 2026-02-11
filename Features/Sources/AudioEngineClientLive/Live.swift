import ComposableArchitecture
import AudioEngineClient
import AudioKit
import Foundation

extension AudioEngineClient: DependencyKey {
    public static let liveValue: AudioEngineClient = {
        let actor = AudioEngineActor()

        return AudioEngineClient(
            loadPreset: { presetId in
                try await actor.loadPreset(presetId: presetId)
            },
            playSample: { path in
                try await actor.playSample(at: path)
            },
            playPad: { padId in
                try await actor.playPad(padId: padId)
            },
            stopAll: {
                await actor.stopAll()
            },
            loadedSamples: {
                return await actor.loadedSamples()
            },
            drumPads: {
                return await actor.drumPads()
            },
            isPresetLoaded: {
                return await actor.isPresetLoaded()
            },
            currentPresetId: {
                return await actor.currentPresetId()
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
            }
        )
    }()
}
