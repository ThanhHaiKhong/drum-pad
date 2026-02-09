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
    private var samples: [Int: AudioEngineClient.Sample] = [:]
    private var pads: [Int: AudioEngineClient.DrumPad] = [:]
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

        // Load the preset file from bundle resources
        guard let presetURL = Bundle.module.url(
            forResource: "drumpad-presets-\(presetId)",
            withExtension: "json",
            subdirectory: "Presets"
        ) else {
            throw AudioEngineClient.Error.loadPresetFailed(
                presetId: presetId,
                underlyingError: NSError(
                    domain: "AudioEngineClient",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Preset file not found in bundle"]
                )
            )
        }

        do {
            let jsonData = try Data(contentsOf: presetURL)
            let decoder = JSONDecoder()
            let presetData = try decoder.decode(AudioEngineClient.PresetData.self, from: jsonData)

            // Convert preset data to samples and pads
            var newSamples: [Int: AudioEngineClient.Sample] = [:]
            var newPads: [Int: AudioEngineClient.DrumPad] = [:]

            for (key, file) in presetData.files {
                if let intKey = Int(key) {
                    // Resolve sample file URL from bundle
                    guard let sampleURL = Bundle.module.url(
                        forResource: file.filename.replacingOccurrences(of: ".wav", with: ""),
                        withExtension: "wav",
                        subdirectory: "Samples"
                    ) else {
                        throw AudioEngineClient.Error.sampleNotFound(path: file.filename)
                    }

                    let sample = AudioEngineClient.Sample(
                        id: intKey,
                        filename: file.filename,
                        name: file.filename.replacingOccurrences(of: ".wav", with: ""),
                        path: sampleURL.absoluteString,
                        color: file.color,
                        chokeGroup: file.choke ?? 0
                    )

                    newSamples[intKey] = sample
                    newPads[intKey] = AudioEngineClient.DrumPad(
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
        } catch {
            let error = AudioEngineClient.Error.loadPresetFailed(presetId: presetId, underlyingError: error)
            logger("Failed to load preset \(presetId): \(error)")
            throw error
        }
    }
    
    func playSample(at path: String) async throws {
        logger("Playing sample at path: \(path)")

        // Convert path string (absolute URL) back to URL
        guard let sampleURL = URL(string: path) else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }

        // Check if we already have a player for this file
        let playerId = path
        var player = players[playerId]

        if player == nil {
            player = AudioPlayer(url: sampleURL)
            engine.output = player!
            players[playerId] = player
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
    
    func loadedSamples() async -> [Int: AudioEngineClient.Sample] {
        return samples
    }

    func drumPads() async -> [Int: AudioEngineClient.DrumPad] {
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
    
    func sampleForPad(padId: Int) async -> AudioEngineClient.Sample? {
        return samples[padId]
    }
}
