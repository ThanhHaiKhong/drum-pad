//
//  Actor.swift
//  AudioEngineClientLive
//

import AudioEngineClient
import AudioKit
import Foundation
import AVFoundation

actor AudioEngineActor {
    private var engine: AudioEngine
    private var players: [String: AudioPlayer] = [:]
    private var samples: [Int: Sample] = [:]
    private var pads: [Int: DrumPad] = [:]
    private var currentPreset: String?
    
    private let logger: @Sendable (String) -> Void

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
            print("🎵 [AUDIO_ENGINE_LIVE_ACTOR]: \(message)")
            #endif
        }
    ) {
        self.engine = AudioEngine()
        self.logger = logger
        
        do {
            try engine.start()
        } catch {
            logger("Audio engine failed to start: \(error)")
        }
    }
    
    func loadPreset(presetId: String) async throws {
        logger("Loading preset: \(presetId)")

        // Construct the path to the preset file
        let presetFilePath = "/Users/thanhhaikhong/Downloads/drumpad-550/drumpad-presets-\(presetId).json"
        
        do {
            // Load the preset file from disk
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: presetFilePath))
            let decoder = JSONDecoder()
            let presetData = try decoder.decode(PresetData.self, from: jsonData)

            // Convert preset data to samples and pads
            var newSamples: [Int: Sample] = [:]
            var newPads: [Int: DrumPad] = [:]

            for (key, file) in presetData.files {
                if let intKey = Int(key) {
                    let sample = Sample(
                        id: intKey,
                        filename: file.filename,
                        name: file.filename.replacingOccurrences(of: ".wav", with: ""),
                        path: "/Users/thanhhaikhong/Downloads/drumpad-550/drumpad-550/\(file.filename)",
                        color: file.color,
                        chokeGroup: file.choke ?? 0
                    )

                    newSamples[intKey] = sample
                    newPads[intKey] = DrumPad(
                        id: intKey,
                        sampleId: sample.id,
                        color: sample.color,
                        chokeGroup: sample.chokeGroup
                    )
                }
            }

            self.samples = newSamples
            self.pads = newPads
            self.currentPreset = presetData.id

            logger("Successfully loaded preset: \(presetId) with \(newSamples.count) samples")
        } catch let decodingError as DecodingError {
            let error = AudioEngineClient.Error.loadPresetFailed(presetId: presetId, underlyingError: decodingError)
            logger("Failed to decode preset \(presetId): \(decodingError)")
            throw error
        } catch let fileError {
            let error = AudioEngineClient.Error.loadPresetFailed(presetId: presetId, underlyingError: fileError)
            logger("Failed to load preset file \(presetFilePath): \(fileError)")
            throw error
        }
    }
    
    func playSample(at path: String) async throws {
        logger("Playing sample at path: \(path)")
        
        // Check if we already have a player for this file
        let playerId = path
        var player = players[playerId]
        
        if player == nil {
            do {
                player = try AudioPlayer(url: URL(fileURLWithPath: path))
                engine.output = player!
                players[playerId] = player
            } catch {
                throw AudioEngineClient.Error.sampleNotFound(path: path)
            }
        }
        
        guard let player = player else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }
        
        player.play()
    }
    
    func playPad(padId: Int) async throws {
        logger("Playing pad with ID: \(padId)")
        
        guard let pad = pads[padId],
              let sample = samples[pad.sampleId] else {
            throw AudioEngineClient.Error.padNotFound(padId: padId)
        }
        
        try await playSample(at: sample.path)
    }
    
    func stopAll() async {
        logger("Stopping all audio playback")
        
        for player in players.values {
            player.stop()
        }
        players.removeAll()
    }
    
    func loadedSamples() async -> [Int: Sample] {
        return samples
    }
    
    func drumPads() async -> [Int: DrumPad] {
        return pads
    }
    
    func isPresetLoaded() async -> Bool {
        return currentPreset != nil
    }
    
    func currentPresetId() async -> String? {
        return currentPreset
    }
    
    func unloadPreset() async {
        logger("Unloading preset")
        samples = [:]
        pads = [:]
        currentPreset = nil
        logger("Preset unloaded")
    }
    
    func sampleForPad(padId: Int) async -> Sample? {
        return samples[padId]
    }
}
