import AudioEngineClient
import AudioKit
import Foundation
import SequenceEngineClient

public final class SequencePlayer: @unchecked Sendable {
    private var isPlaying = false
    private var currentStep = 0
    private var totalSteps = 0
    private var stepDuration: TimeInterval = 0
    private var shouldLoop = false
    
    private var currentPattern: AudioEngineClient.Pattern?
    private var currentTempo: Int = 0
    
    private let engine: AudioEngine
    private let mixer: Mixer
    private var players: [Int: AudioPlayer] = [:]
    
    private let getDrumPads: () async -> [AudioEngineClient.DrumPad]
    private let logger: (String) -> Void
    
    public init(
        engine: AudioEngine,
        getDrumPads: @escaping () async -> [AudioEngineClient.DrumPad],
        logger: @escaping (String) -> Void = { _ in }
    ) {
        self.engine = engine
        self.mixer = Mixer()
        self.getDrumPads = getDrumPads
        self.logger = logger
        
        engine.output = mixer
        
        do {
            try engine.start()
        } catch {
            logger("❌ Failed to start audio engine: \(error)")
        }
    }
    
    deinit {
        engine.stop()
        players.removeAll()
        logger("🧹 SequencePlayer deallocated")
    }
    
    public func play(
        pattern: AudioEngineClient.Pattern,
        tempo: Int,
        loop: Bool = false
    ) async {
        await stop()
        
        currentPattern = pattern
        currentTempo = tempo
        shouldLoop = loop
        totalSteps = pattern.sequencerSize
        currentStep = 0
        isPlaying = true
        
        stepDuration = 60.0 / (Double(tempo) * 4.0)
        
        logger("🎵 Playing '\(pattern.name)' @ \(tempo) BPM, \(totalSteps) steps")
        
        await playbackLoop()
    }
    
    public func stop() async {
        isPlaying = false
        currentPattern = nil
        currentStep = 0
        
        for (_, player) in players {
            player.stop()
        }
        players.removeAll()
        
        logger("⏹️ Stopped")
    }
    
    private func playbackLoop() async {
        guard let pattern = currentPattern, isPlaying else { return }
        
        for step in 0..<totalSteps {
            guard isPlaying else { break }
            
            currentStep = step
            logger("🔁 Step \(step)/\(totalSteps - 1)")
            
            await playStep(pattern, step: step)
            try? await Task.sleep(for: .seconds(stepDuration))
        }
        
        if shouldLoop {
            logger("🔁 Looping")
            await play(pattern: pattern, tempo: currentTempo, loop: true)
        } else {
            logger("✅ Completed")
            await stop()
        }
    }
    
    private func playStep(_ pattern: AudioEngineClient.Pattern, step: Int) async {
        let drumPads = await getDrumPads()
        
        for padSequence in pattern.padSequences {
            if padSequence.playsAtStep(step) {
                guard let pad = drumPads.first(where: { $0.id == padSequence.padId }),
                      let sampleURL = URL(string: pad.sample.path) else {
                    logger("⚠️ Pad \(padSequence.padId) not found")
                    continue
                }
                
                do {
                    let player = try await getOrCreatePlayer(for: padSequence.padId, url: sampleURL)
                    player.stop()
                    player.seek(time: 0)
                    player.play()
                    logger("🥁 Step \(step): Pad \(padSequence.padId)")
                } catch {
                    logger("❌ Step \(step): Pad \(padSequence.padId) failed: \(error)")
                }
            }
        }
    }
    
    private func getOrCreatePlayer(for padId: Int, url: URL) async throws -> AudioPlayer {
        if let existingPlayer = players[padId] {
            return existingPlayer
        }
        
        let player = AudioPlayer()
        try player.load(url: url)
        
        mixer.addInput(player)
        players[padId] = player
        
        return player
    }
}
