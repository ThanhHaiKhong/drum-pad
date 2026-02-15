//
//  Mocks.swift
//  AudioEngine
//

import Dependencies

extension DependencyValues {
    public var audioEngine: AudioEngineClient {
        get { self[AudioEngineClient.self] }
        set { self[AudioEngineClient.self] = newValue }
    }
}

extension AudioEngineClient: TestDependencyKey {
    public static let previewValue = Self()
    public static let testValue = Self()
}
