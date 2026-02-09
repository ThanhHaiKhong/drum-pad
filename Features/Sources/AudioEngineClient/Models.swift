//
//  Models.swift
//  AudioEngine
//

import Foundation
import ComposableArchitecture

// MARK: - Sample

/// Represents an audio sample
public struct Sample: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let filename: String
    public let name: String
    public let path: String
    public let color: String
    public let chokeGroup: Int
    
    public init(id: Int, filename: String, name: String, path: String, color: String, chokeGroup: Int) {
        self.id = id
        self.filename = filename
        self.name = name
        self.path = path
        self.color = color
        self.chokeGroup = chokeGroup
    }
}

// MARK: - DrumPad

/// Represents a drum pad
public struct DrumPad: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let sampleId: Int
    public let color: String
    public let chokeGroup: Int
    
    public init(id: Int, sampleId: Int, color: String, chokeGroup: Int) {
        self.id = id
        self.sampleId = sampleId
        self.color = color
        self.chokeGroup = chokeGroup
    }
}

// MARK: - PresetData

/// Represents a preset configuration
public struct PresetData: Codable, Sendable {
    public let id: String
    public let name: String
    public let files: [String: PresetFile]
    
    public init(id: String, name: String, files: [String : PresetFile]) {
        self.id = id
        self.name = name
        self.files = files
    }
}

public struct PresetFile: Codable, Sendable {
    public let id: String
    public let filename: String
    public let color: String
    public let choke: Int?
    
    public init(id: String, filename: String, color: String, choke: Int?) {
        self.id = id
        self.filename = filename
        self.color = color
        self.choke = choke
    }
}

// MARK: - AudioEngineState

/// Represents the state of the audio engine
public struct AudioEngineState: Codable, Equatable, Sendable {
    public var samples: [Int: Sample] = [:]
    public var pads: [Int: DrumPad] = [:]
    public var isPlaying: Bool = false
    public var currentPreset: String = ""
    public var loadedSamplesCount: Int = 0
    public var totalSamplesCount: Int = 0
    
    public init() {}
}

// MARK: - AudioEngineError

extension AudioEngineClient {
    /// Errors that can occur during audio engine operations
    public enum `Error`: Swift.Error, Sendable, LocalizedError {
        /// Failed to load a preset
        case loadPresetFailed(presetId: String, underlyingError: Swift.Error)
        
        /// Failed to play a sample
        case playSampleFailed(path: String, underlyingError: Swift.Error)
        
        /// Sample not found
        case sampleNotFound(path: String)
        
        /// Pad not found
        case padNotFound(padId: Int)
        
        public var errorDescription: String? {
            switch self {
            case .loadPresetFailed(let presetId, let error):
                return "Failed to load preset \(presetId): \(error.localizedDescription)"
            case .playSampleFailed(let path, let error):
                return "Failed to play sample at \(path): \(error.localizedDescription)"
            case .sampleNotFound(let path):
                return "Sample not found at path: \(path)"
            case .padNotFound(let padId):
                return "Drum pad not found with ID: \(padId)"
            }
        }
    }
}