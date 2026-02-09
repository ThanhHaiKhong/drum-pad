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
    private let delegate: AudioEngineDelegate

    init(
        logger: @escaping @Sendable (String) -> Void = { message in
            #if DEBUG
            print("🎵 [AUDIO_ENGINE_LIVE_ACTOR]: \(message)")
            #endif
        }
    ) {
        self.engine = AudioEngine()
        self.logger = logger
        self.delegate = AudioEngineDelegate(logger: logger)

        let mixer = Mixer()
        engine.output = mixer

        do {
            try engine.start()
            logger("Audio engine started successfully")
        } catch {
            logger("Audio engine failed to start: \(error)")
        }
    }

    func loadPreset(presetId: String) async throws {
        logger("Loading preset: \(presetId)")

        if let presetURL = delegate.findPresetFile(named: presetId) {
            let (newSamples, newPads) = try await delegate.loadPresetFromURL(presetURL, presetId: presetId)

            self.samples = newSamples
            self.pads = newPads
            self.currentPreset = presetId

            logger("Successfully loaded preset: \(presetId) with \(newSamples.count) samples")
        } else {
            logger("Preset file not found in bundle, creating a minimal default preset with actual file paths")
            let (defaultSamples, defaultPads) = delegate.createDefaultPreset(presetId: presetId)

            self.samples = defaultSamples
            self.pads = defaultPads
            self.currentPreset = presetId

            logger("Created default preset with \(defaultSamples.count) samples, \(defaultSamples.values.filter { !$0.path.isEmpty }.count) with actual file paths")
        }
    }

    func playSample(at path: String) async throws {
        logger("Playing sample at path: \(path)")

        if path.isEmpty {
            logger("Empty path detected - simulating audio playback for fallback sample")
            try await Task.sleep(nanoseconds: UInt64(100 * 1_000_000))
            return
        }

        guard let sampleURL = URL(string: path) else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }

        let playerId = path
        var player = players[playerId]

        if player == nil {
            let newPlayer = AudioPlayer()
            try newPlayer.load(url: sampleURL)

            if let mixer = engine.output as? Mixer {
                let newMixer = Mixer(mixer, newPlayer)
                engine.output = newMixer
            } else {
                engine.output = newPlayer
            }
            player = newPlayer
            players[playerId] = player
        }

        guard let player = player else {
            throw AudioEngineClient.Error.sampleNotFound(path: path)
        }

        // Always reset the player to the beginning before playing
        player.seek(time: 0.0)
        
        // Stop the player if it's currently playing to ensure it restarts
        if player.status == .playing {
            player.stop()
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
