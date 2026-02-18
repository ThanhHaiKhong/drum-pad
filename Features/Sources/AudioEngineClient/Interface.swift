//
//  Interface.swift
//  AudioEngine
//

import ComposableArchitecture
import Foundation

@DependencyClient
public struct AudioEngineClient: Sendable {
    public var loadPreset: @Sendable (_ presetId: String) async throws -> Void = { _ in }
    public var playPad: @Sendable (_ padID: AudioEngineClient.DrumPad.ID) async throws -> Void = { _ in }
    public var drumPads: @Sendable () async -> [AudioEngineClient.DrumPad] = { [] }
    public var currentPresetID: @Sendable () async -> String? = { nil }
    public var startRecording: @Sendable () async throws -> Void = { }
    public var stopRecording: @Sendable () async throws -> String? = { nil }
    public var isRecording: @Sendable () async -> Bool = { false }
    public var playRecordedAudio: @Sendable () async throws -> Void = { }
    public var positionUpdates: @Sendable (_ padID: AudioEngineClient.DrumPad.ID) async -> AsyncStream<AudioEngineClient.PositionUpdate> = { _ in AsyncStream { _ in } }
    public var currentTempo: @Sendable () async -> Int = { 0 }
    public var preset: @Sendable () async -> AudioEngineClient.Preset? = { nil }
}
