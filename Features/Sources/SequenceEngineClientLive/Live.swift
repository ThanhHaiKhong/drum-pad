import ComposableArchitecture
import AudioEngineClient
import AudioKit
import Foundation
import SequenceEngineClient

extension SequenceEngineClient: DependencyKey {
    public static let liveValue: SequenceEngineClient = {
        let sequenceEngine = AudioEngine()
        
        let player = SequencePlayer(
            engine: sequenceEngine,
            getDrumPads: {
                @Dependency(\.audioEngine) var audioEngine
                return await audioEngine.drumPads()
            },
            logger: { message in
                #if DEBUG
                print("🎵 [SEQUENCE_PLAYER]: \(message)")
                #endif
            }
        )
        
        return SequenceEngineClient(
            playSequence: { pattern, tempo, loop in
                await player.play(pattern: pattern, tempo: tempo, loop: loop)
            },
            playSequenceWithClick: { pattern, tempo, loop, clickTrackEnabled in
                await player.play(pattern: pattern, tempo: tempo, loop: loop)
            },
            stopSequence: {
                await player.stop()
            },
            pauseSequence: {
                await player.stop()
            },
            resumeSequence: { },
            toggleSequencePlayPause: { },
            sequenceState: {
                (false, false, 0, 0)
            },
            sequenceProgressUpdates: {
                AsyncStream { _ in }
            }
        )
    }()
}
