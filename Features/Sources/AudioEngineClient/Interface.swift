//
//  Interface.swift
//  AudioEngine
//

import ComposableArchitecture
import Foundation

/// A dependency client for managing audio samples and playback for drum pad applications.
///
/// `AudioEngineClient` provides a testable, injectable interface for loading and playing
/// audio samples, managing drum pad presets, and handling audio playback operations.
/// It supports dependency injection through the Composable Architecture's dependency system.
///
/// ## Usage
///
/// ```swift
/// @Dependency(\.audioEngine) var audioEngine
///
/// // Load a preset
/// await audioEngine.loadPreset("550")
///
/// // Play a sample
/// try await audioEngine.playSample(at: "/path/to/sample.wav")
/// ```
///
/// ## Testing
///
/// Use the provided mock implementations for testing:
/// - `.happy` - Successful scenarios with mock audio operations
/// - `.failing` - Error scenarios for failure testing
/// - `.noop` - Silent no-op implementation
@DependencyClient
public struct AudioEngineClient: Sendable {

    /// Loads a preset configuration with drum pad samples.
    ///
    /// - Parameter presetId: The identifier of the preset to load
    /// - Throws: An error if the preset cannot be loaded
    public var loadPreset: @Sendable (_ presetId: String) async throws -> Void = { _ in }

    /// Plays a sample at the specified path.
    ///
    /// - Parameter path: The file path of the audio sample to play
    /// - Throws: An error if the sample cannot be played
    public var playSample: @Sendable (_ path: String) async throws -> Void = { _ in }

    /// Plays a sample for a specific drum pad.
    ///
    /// - Parameter padId: The identifier of the drum pad to trigger
    /// - Throws: An error if the sample cannot be played
    public var playPad: @Sendable (_ padId: Int) async throws -> Void = { _ in }

    /// Stops all audio playback.
    public var stopAll: @Sendable () async -> Void = { }

    /// Returns the current list of loaded samples.
    ///
    /// - Returns: A dictionary mapping pad IDs to sample information
    public var loadedSamples: @Sendable () async -> [Int: AudioEngineClient.Sample] = { [:] }

    /// Returns the current list of drum pads.
    ///
    /// - Returns: A dictionary mapping pad IDs to drum pad information
    public var drumPads: @Sendable () async -> [Int: AudioEngineClient.DrumPad] = { [:] }

    /// Checks if a preset is currently loaded.
    ///
    /// - Returns: True if a preset is loaded, false otherwise
    public var isPresetLoaded: @Sendable () async -> Bool = { false }

    /// Gets the current preset ID.
    ///
    /// - Returns: The identifier of the currently loaded preset, or nil if none
    public var currentPresetId: @Sendable () async -> String? = { nil }

    /// Unloads the currently loaded preset.
    public var unloadPreset: @Sendable () async -> Void = { }

    /// Gets the sample associated with a specific pad ID.
    ///
    /// - Parameter padId: The identifier of the drum pad
    /// - Returns: The sample associated with the pad, or nil if not found
    public var sampleForPad: @Sendable (_ padId: Int) async -> AudioEngineClient.Sample? = { _ in nil }
}