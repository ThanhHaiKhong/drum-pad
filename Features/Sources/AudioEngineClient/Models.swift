//
//  Models.swift
//  AudioEngine
//

import Foundation
import ComposableArchitecture

// MARK: - Preset (Main Model)

extension AudioEngineClient {
    /// Complete preset model matching drumpad-presets-*.json structure
    public struct Preset: Codable, Sendable {
        // MARK: - Identity
        public let id: String
        public let orderBy: String
        public let name: String
        
        // MARK: - Metadata
        public let price: Int
        public let tempo: Int
        public let timestamp: TimeInterval
        
        // MARK: - Preview & Media
        public let audioPreview1Name: String
        public let audioPreview1URL: String
        public let imagePreview1: String
        public let icon: String
        
        // MARK: - Author & Tags
        public let author: String
        public let tags: [String]
        
        // MARK: - Pads (converted from files dictionary)
        public let pads: [DrumPad]
        
        // MARK: - Tutorials
        public let beatSchool: BeatSchool
        
        enum CodingKeys: String, CodingKey {
            case id, orderBy, name, price, tempo, timestamp
            case audioPreview1Name, audioPreview1URL, imagePreview1, icon
            case author, tags
            case files
            case beatSchool
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            id = try container.decode(String.self, forKey: .id)
            orderBy = try container.decode(String.self, forKey: .orderBy)
            name = try container.decode(String.self, forKey: .name)
            price = try container.decode(Int.self, forKey: .price)
            tempo = try container.decode(Int.self, forKey: .tempo)
            timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
            audioPreview1Name = try container.decode(String.self, forKey: .audioPreview1Name)
            audioPreview1URL = try container.decode(String.self, forKey: .audioPreview1URL)
            imagePreview1 = try container.decode(String.self, forKey: .imagePreview1)
            icon = try container.decode(String.self, forKey: .icon)
            author = try container.decode(String.self, forKey: .author)
            tags = try container.decode([String].self, forKey: .tags)
            beatSchool = try container.decode(BeatSchool.self, forKey: .beatSchool)

            // Decode files dictionary and convert to [DrumPad] array
            let filesDict = try container.decode([String: PresetFile].self, forKey: .files)
            self.pads = filesDict.compactMap { key, file in
                guard let id = Int(key) else { return nil }
                return DrumPad(
                    id: id,
                    sample: DrumPad.Sample(
                        id: id,
                        filename: file.filename,
                        name: file.filename.replacingOccurrences(of: ".wav", with: ""),
                        path: ""
                    ),
                    color: file.color,
                    chokeGroup: file.choke ?? 0
                )
            }.sorted { $0.id < $1.id }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(orderBy, forKey: .orderBy)
            try container.encode(name, forKey: .name)
            try container.encode(price, forKey: .price)
            try container.encode(tempo, forKey: .tempo)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(audioPreview1Name, forKey: .audioPreview1Name)
            try container.encode(audioPreview1URL, forKey: .audioPreview1URL)
            try container.encode(imagePreview1, forKey: .imagePreview1)
            try container.encode(icon, forKey: .icon)
            try container.encode(author, forKey: .author)
            try container.encode(tags, forKey: .tags)
            try container.encode(beatSchool, forKey: .beatSchool)
            // Note: pads is not encoded back to files - it's a derived property
            // For re-encoding, we'd need to convert pads back to files dictionary
        }
        
        /// Public initializer for creating Preset instances (e.g., for mocks)
        public init(
            id: String,
            orderBy: String,
            name: String,
            price: Int,
            tempo: Int,
            timestamp: TimeInterval,
            audioPreview1Name: String,
            audioPreview1URL: String,
            imagePreview1: String,
            icon: String,
            author: String,
            tags: [String],
            pads: [DrumPad],
            beatSchool: BeatSchool
        ) {
            self.id = id
            self.orderBy = orderBy
            self.name = name
            self.price = price
            self.tempo = tempo
            self.timestamp = timestamp
            self.audioPreview1Name = audioPreview1Name
            self.audioPreview1URL = audioPreview1URL
            self.imagePreview1 = imagePreview1
            self.icon = icon
            self.author = author
            self.tags = tags
            self.pads = pads
            self.beatSchool = beatSchool
        }
    }
}

// MARK: - PresetFile (Private Decoding Helper)

extension AudioEngineClient.Preset {
    /// Internal model for decoding JSON files dictionary
    struct PresetFile: Codable {
        let filename: String
        let color: String
        let choke: Int?
    }
}

// MARK: - BeatSchool

extension AudioEngineClient {
    /// BeatSchool tutorial patterns container
    public struct BeatSchool: Codable, Sendable {
        public let v0: [Pattern]
        public let v1: [Pattern]
        
        /// Get patterns by version
        public func patterns(forVersion version: Int) -> [Pattern] {
            switch version {
            case 0: return v0
            case 1: return v1
            default: return []
            }
        }
    }
}

// MARK: - Pattern

extension AudioEngineClient {
    /// A single tutorial pattern with sequencer steps
    public struct Pattern: Codable, Identifiable, Sendable {
        public let id: Int
        public let version: Int
        public let name: String
        public let sequencerSize: Int
        public let pads: [String: [PatternNote]]
        public let orderBy: Int
        
        // MARK: - Computed Properties for Easy Access
        
        /// All pad sequences as array (excludes "undefined")
        public var padSequences: [PadSequence] {
            pads.compactMap { key, notes in
                guard key != "undefined", let padId = Int(key) else { return nil }
                // Pattern uses 0-based indexing, convert to 1-based pad IDs
                return PadSequence(padId: padId + 1, notes: notes)
            }.sorted { $0.padId < $1.padId }
        }
        
        /// Undefined events (click track, markers)
        public var undefinedEvents: [PatternNote] {
            pads["undefined"] ?? []
        }
        
        /// Get notes for a specific pad
        public func notes(forPadId padId: Int) -> [PatternNote] {
            pads[String(padId)] ?? []
        }
        
        /// Check if pad has notes
        public func hasNotes(forPadId padId: Int) -> Bool {
            notes(forPadId: padId).isEmpty == false
        }
    }
}

// MARK: - PadSequence

extension AudioEngineClient {
    /// Sequence of notes for a specific pad in a pattern
    public struct PadSequence: Identifiable, Sendable {
        public let padId: Int
        public let notes: [PatternNote]
        
        public var id: Int { padId }
        
        /// Check if this pad plays at a specific step
        public func playsAtStep(_ step: Int) -> Bool {
            notes.contains { $0.start == step }
        }
        
        /// All steps where this pad plays
        public var steps: [Int] {
            notes.map { $0.start }
        }
    }
}

// MARK: - PatternNote

extension AudioEngineClient {
    /// A single note event in a pattern (sequencer step)
    public struct PatternNote: Codable, Sendable {
        public let start: Int
        
        /// Create a note at a specific step
        public init(start: Int) {
            self.start = start
        }
    }
}

// MARK: - PresetData (Legacy Support)

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

// MARK: - DrumPad

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

// MARK: - PositionUpdate

extension AudioEngineClient {
    public typealias PositionUpdate = (padId: AudioEngineClient.DrumPad.ID, currentTime: TimeInterval, duration: TimeInterval)
}

// MARK: - Error

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
