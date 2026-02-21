//
//  Models.swift
//  SequenceEngineClient
//

import Foundation
import AudioEngineClient

/// Sequence playback progress update for UI
public struct SequencePlaybackProgress: Sendable {
    public let currentStep: Int
    public let totalSteps: Int
    public let isPlaying: Bool
    public let patternName: String
    public let tempo: Int
    
    public init(
        currentStep: Int,
        totalSteps: Int,
        isPlaying: Bool,
        patternName: String = "",
        tempo: Int = 0
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.isPlaying = isPlaying
        self.patternName = patternName
        self.tempo = tempo
    }
    
    /// Progress percentage (0.0 to 1.0)
    public var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }
}

// Type alias for backwards compatibility
public typealias PatternPlaybackProgress = SequencePlaybackProgress
