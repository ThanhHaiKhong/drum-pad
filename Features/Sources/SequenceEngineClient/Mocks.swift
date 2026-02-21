//
//  Mocks.swift
//  SequenceEngineClient
//

import Dependencies
import AudioEngineClient

extension DependencyValues {
    public var sequenceEngine: SequenceEngineClient {
        get { self[SequenceEngineClient.self] }
        set { self[SequenceEngineClient.self] = newValue }
    }
}

extension SequenceEngineClient: TestDependencyKey {
    public static var previewValue: Self {
        var client = Self()
        
        client.playSequence = { pattern, tempo, loop in
            print("▶️ Sequence '\(pattern.name)' @ \(tempo) BPM, loop=\(loop)")
        }
        
        client.playSequenceWithClick = { pattern, tempo, loop, clickTrackEnabled in
            let click = clickTrackEnabled ? "with 🔔" : "no click"
            print("▶️ Sequence '\(pattern.name)' @ \(tempo) BPM (\(click))")
        }
        
        client.stopSequence = {
            print("⏹️ Sequence stopped")
        }
        
        client.pauseSequence = {
            print("⏸️ Sequence paused")
        }
        
        client.resumeSequence = {
            print("▶️ Sequence resumed")
        }
        
        client.toggleSequencePlayPause = {
            print("🔄 Toggled play/pause")
        }
        
        client.sequenceState = {
            return (false, false, 0, 17)
        }
        
        client.sequenceProgressUpdates = {
            AsyncStream { _ in }
        }
        
        return client
    }
    
    public static let testValue = Self()
}
