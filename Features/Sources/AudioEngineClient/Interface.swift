//
//  Interface.swift
//  AudioEngine
//

import ComposableArchitecture
import Foundation

@DependencyClient
public struct AudioEngineClient: Sendable {
    public var loadPreset: @Sendable (_ presetId: String) async throws -> Void = { _ in }
    public var playSample: @Sendable (_ path: String) async throws -> Void = { _ in }
    public var playPad: @Sendable (_ padId: Int) async throws -> Void = { _ in }
    public var stopAll: @Sendable () async -> Void = { }
    public var loadedSamples: @Sendable () async -> [Int: AudioEngineClient.Sample] = { [:] }
    public var drumPads: @Sendable () async -> [Int: AudioEngineClient.DrumPad] = { [:] }
    public var isPresetLoaded: @Sendable () async -> Bool = { false }
    public var currentPresetId: @Sendable () async -> String? = { nil }
    public var startRecording: @Sendable () async throws -> Void = { }
    public var stopRecording: @Sendable () async throws -> String? = { nil }
    public var isRecording: @Sendable () async -> Bool = { false }
    public var playRecordedAudio: @Sendable () async throws -> Void = { }
}
