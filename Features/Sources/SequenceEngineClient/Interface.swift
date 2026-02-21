//
//  Interface.swift
//  SequenceEngineClient
//

import ComposableArchitecture
import Foundation
import AudioEngineClient

@DependencyClient
public struct SequenceEngineClient: Sendable {
    /// Play a sequence/pattern with tempo
    public var playSequence: @Sendable (
        _ pattern: AudioEngineClient.Pattern,
        _ tempo: Int,
        _ loop: Bool
    ) async -> Void = { _, _, _ in }
    
    /// Play a sequence with click track
    public var playSequenceWithClick: @Sendable (
        _ pattern: AudioEngineClient.Pattern,
        _ tempo: Int,
        _ loop: Bool,
        _ clickTrackEnabled: Bool
    ) async -> Void = { _, _, _, _ in }
    
    /// Stop sequence playback
    public var stopSequence: @Sendable () async -> Void = { }
    
    /// Pause sequence playback
    public var pauseSequence: @Sendable () async -> Void = { }
    
    /// Resume paused sequence playback
    public var resumeSequence: @Sendable () async -> Void = { }
    
    /// Toggle play/pause
    public var toggleSequencePlayPause: @Sendable () async -> Void = { }
    
    /// Get current sequence playback state
    public var sequenceState: @Sendable () async -> (
        isPlaying: Bool,
        isPaused: Bool,
        currentStep: Int,
        totalSteps: Int
    ) = { (false, false, 0, 0) }
    
    /// Subscribe to sequence playback progress
    public var sequenceProgressUpdates: @Sendable () async -> AsyncStream<SequencePlaybackProgress> = {
        AsyncStream { _ in }
    }
}
