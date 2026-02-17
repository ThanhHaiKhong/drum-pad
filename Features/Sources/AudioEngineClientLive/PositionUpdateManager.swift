import AudioEngineClient
import Foundation

/// An actor that manages position update continuations in a thread-safe manner
actor PositionUpdateManager {
    private var positionContinuations: [AudioEngineClient.DrumPad.ID: AsyncStream<AudioEngineClient.PositionUpdate>.Continuation] = [:]
    
    /// Adds a continuation for a specific pad ID
    func addContinuation(for padID: AudioEngineClient.DrumPad.ID, continuation: AsyncStream<AudioEngineClient.PositionUpdate>.Continuation) {
        positionContinuations[padID] = continuation
    }
    
    /// Removes a continuation for a specific pad ID
    func removeContinuation(for padID: AudioEngineClient.DrumPad.ID) {
        positionContinuations[padID] = nil
    }
    
    /// Gets a continuation for a specific pad ID
    func getContinuation(for padID: AudioEngineClient.DrumPad.ID) -> AsyncStream<AudioEngineClient.PositionUpdate>.Continuation? {
        return positionContinuations[padID]
    }
    
    /// Checks if a continuation exists for a specific pad ID
    func hasContinuation(for padID: AudioEngineClient.DrumPad.ID) -> Bool {
        return positionContinuations[padID] != nil
    }
    
    /// Gets all pad IDs that have active continuations
    func getAllActivePadIDs() -> [AudioEngineClient.DrumPad.ID] {
        return Array(positionContinuations.keys)
    }
}