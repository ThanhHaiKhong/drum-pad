//
//  Mocks.swift
//  AudioEngine
//

import Dependencies
import Foundation

// MARK: - Constants

private enum MockConstants {
    /// Mock play delay in nanoseconds (50ms) - simulates audio processing time
    static let playDelayNanoseconds: UInt64 = 50_000_000

    /// Load delay in nanoseconds (100ms) - simulates preset loading time
    static let loadDelayNanoseconds: UInt64 = 100_000_000
}

extension DependencyValues {
    public var audioEngine: AudioEngineClient {
        get { self[AudioEngineClient.self] }
        set { self[AudioEngineClient.self] = newValue }
    }
}

extension AudioEngineClient: TestDependencyKey {
    public static let previewValue = Self.happy
    public static let testValue = Self()
}

extension AudioEngineClient {
    /// A no-op implementation that performs no actions.
    ///
    /// Useful for tests where you want to ensure no audio operations occur.
    public static let noop = Self(
        loadPreset: { _ in },
        playSample: { _ in },
        playPad: { _ in },
        stopAll: { },
        loadedSamples: { [:] },
        drumPads: { [:] },
        isPresetLoaded: { false },
        currentPresetId: { nil },
        unloadPreset: { },
        sampleForPad: { _ in nil }
    )

    /// A failing implementation that throws errors for operations.
    ///
    /// Useful for testing error handling paths in your code.
    public static let failing = Self(
        loadPreset: { presetId in
            try await Task.sleep(nanoseconds: MockConstants.loadDelayNanoseconds)
            throw URLError(.badServerResponse)
        },
        playSample: { path in
            try await Task.sleep(nanoseconds: MockConstants.playDelayNanoseconds)
            throw URLError(.cannotDecodeContentData)
        },
        playPad: { padId in
            try await Task.sleep(nanoseconds: MockConstants.playDelayNanoseconds)
            throw URLError(.cannotDecodeContentData)
        },
        stopAll: { },
        loadedSamples: { [:] },
        drumPads: { [:] },
        isPresetLoaded: { false },
        currentPresetId: { nil },
        unloadPreset: { },
        sampleForPad: { _ in nil }
    )

    /// A successful implementation with mock audio operations.
    ///
    /// Simulates successful sample loading and playback with small delays.
    public static let happy = Self(
        loadPreset: { presetId in
            try await Task.sleep(nanoseconds: MockConstants.loadDelayNanoseconds)
        },
        playSample: { path in
            try await Task.sleep(nanoseconds: MockConstants.playDelayNanoseconds)
        },
        playPad: { padId in
            try await Task.sleep(nanoseconds: MockConstants.playDelayNanoseconds)
        },
        stopAll: { },
        loadedSamples: {
            [
                1: Sample(
                    id: 1,
                    filename: "01.wav",
                    name: "Kick",
                    path: "/mock/path/01.wav",
                    color: "red",
                    chokeGroup: 0
                ),
                2: Sample(
                    id: 2,
                    filename: "02.wav",
                    name: "Snare",
                    path: "/mock/path/02.wav",
                    color: "blue",
                    chokeGroup: 0
                )
            ]
        },
        drumPads: {
            [
                1: DrumPad(
                    id: 1,
                    sampleId: 1,
                    color: "red",
                    chokeGroup: 0
                ),
                2: DrumPad(
                    id: 2,
                    sampleId: 2,
                    color: "blue",
                    chokeGroup: 0
                )
            ]
        },
        isPresetLoaded: { true },
        currentPresetId: { "550" },
        unloadPreset: { },
        sampleForPad: { padId in
            [
                1: Sample(
                    id: 1,
                    filename: "01.wav",
                    name: "Kick",
                    path: "/mock/path/01.wav",
                    color: "red",
                    chokeGroup: 0
                ),
                2: Sample(
                    id: 2,
                    filename: "02.wav",
                    name: "Snare",
                    path: "/mock/path/02.wav",
                    color: "blue",
                    chokeGroup: 0
                )
            ][padId]
        }
    )

    /// A mock that simulates a loaded preset with multiple samples
    public static let withLoadedPreset = Self(
        loadPreset: { presetId in
            try await Task.sleep(nanoseconds: MockConstants.loadDelayNanoseconds)
        },
        playSample: { path in
            try await Task.sleep(nanoseconds: MockConstants.playDelayNanoseconds)
        },
        playPad: { padId in
            try await Task.sleep(nanoseconds: MockConstants.playDelayNanoseconds)
        },
        stopAll: { },
        loadedSamples: {
            // Generate 24 samples based on the drum pad structure
            var samples: [Int: Sample] = [:]
            for i in 1...24 {
                samples[i] = Sample(
                    id: i,
                    filename: String(format: "%02d.wav", i),
                    name: "Sample \(i)",
                    path: "/mock/path/\(String(format: "%02d.wav", i))",
                    color: ["red", "blue", "green", "yellow", "purple"].randomElement()!,
                    chokeGroup: i % 4
                )
            }
            return samples
        },
        drumPads: {
            var pads: [Int: DrumPad] = [:]
            for i in 1...24 {
                pads[i] = DrumPad(
                    id: i,
                    sampleId: i,
                    color: ["red", "blue", "green", "yellow", "purple"].randomElement()!,
                    chokeGroup: i % 4
                )
            }
            return pads
        },
        isPresetLoaded: { true },
        currentPresetId: { "550" },
        unloadPreset: { },
        sampleForPad: { padId in
            // Generate sample based on padId
            let samples = (1...24).reduce(into: [Int: Sample]()) { result, i in
                result[i] = Sample(
                    id: i,
                    filename: String(format: "%02d.wav", i),
                    name: "Sample \(i)",
                    path: "/mock/path/\(String(format: "%02d.wav", i))",
                    color: ["red", "blue", "green", "yellow", "purple"].randomElement()!,
                    chokeGroup: i % 4
                )
            }
            return samples[padId]
        }
    )
}