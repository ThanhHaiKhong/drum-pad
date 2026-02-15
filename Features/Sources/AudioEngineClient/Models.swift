//
//  Models.swift
//  AudioEngine
//

import Foundation
import ComposableArchitecture

extension AudioEngineClient {
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
}

extension AudioEngineClient.PresetData {
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
}

extension AudioEngineClient {
    public struct DrumPad: Codable, Identifiable, Equatable, Sendable {
        public let id: Int
        public let sample: Sample
        public let color: String
        public let chokeGroup: Int

        public init(id: Int, sample: Sample, color: String, chokeGroup: Int) {
            self.id = id
            self.sample = sample
            self.color = color
            self.chokeGroup = chokeGroup
        }
    }
}

extension AudioEngineClient.DrumPad {
    public struct Sample: Codable, Identifiable, Equatable, Sendable {
        public let id: Int
        public let filename: String
        public let name: String
        public let path: String

        public init(
            id: Int,
            filename: String,
            name: String,
            path: String
        ) {
            self.id = id
            self.filename = filename
            self.name = name
            self.path = path
        }
    }
}

extension AudioEngineClient {
    public struct State: Codable, Equatable, Sendable {
        public var currentPreset: String = ""
        public var pads: [DrumPad] = []
        public var isPlaying: Bool = false

        public init() {}
    }
}

extension AudioEngineClient {
    public enum `Error`: Swift.Error, Sendable, LocalizedError {
        case loadPresetFailed(presetId: String, underlyingError: Swift.Error)
        case playSampleFailed(path: String, underlyingError: Swift.Error)
        case sampleNotFound(path: String)
        case padNotFound(padId: Int)
        case recordingInProgress
        case invalidPadId(Int)
        case startRecordingFailed(underlyingError: Swift.Error)
        case stopRecordingFailed(underlyingError: Swift.Error)
        case playerNotInitialized(path: String)

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
            case .recordingInProgress:
                return "Cannot perform operation while recording is in progress"
            case .invalidPadId(let padId):
                return "Invalid pad ID for recording: \(padId)"
            case .startRecordingFailed(let error):
                return "Failed to start recording: \(error.localizedDescription)"
            case .stopRecordingFailed(let error):
                return "Failed to stop recording: \(error.localizedDescription)"
            case .playerNotInitialized(let path):
                return "Player not initialized for path: \(path)"
            }
        }
    }
}
