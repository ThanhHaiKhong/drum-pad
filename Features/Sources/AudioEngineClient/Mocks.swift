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
    public static var previewValue: Self {
        var client = Self()
        client.currentTempo = { 90 }
        client.preset = {
            AudioEngineClient.Preset(
                id: "550",
                orderBy: "487",
                name: "Urban Hip-Hop",
                price: 10,
                tempo: 90,
                timestamp: 0,
                audioPreview1Name: "Urban Hip-Hop",
                audioPreview1URL: "",
                imagePreview1: "",
                icon: "",
                author: "BLGN",
                tags: ["#new", "#hiphop"],
                pads: [],
                beatSchool: BeatSchool(v0: [], v1: [])
            )
        }

        return client
    }

    public static let testValue = Self()
}
