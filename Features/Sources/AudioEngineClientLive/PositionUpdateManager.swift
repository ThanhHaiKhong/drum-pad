import AudioEngineClient
import Foundation

actor PositionUpdateManager {
    private var positionContinuations: [AudioEngineClient.DrumPad.ID: AsyncStream<AudioEngineClient.PositionUpdate>.Continuation] = [:]
    
    func addContinuation(for padID: AudioEngineClient.DrumPad.ID, continuation: AsyncStream<AudioEngineClient.PositionUpdate>.Continuation) {
        positionContinuations[padID] = continuation
    }
    
    func removeContinuation(for padID: AudioEngineClient.DrumPad.ID) {
        positionContinuations[padID] = nil
    }
    
    func getContinuation(for padID: AudioEngineClient.DrumPad.ID) -> AsyncStream<AudioEngineClient.PositionUpdate>.Continuation? {
        return positionContinuations[padID]
    }
    
    func hasContinuation(for padID: AudioEngineClient.DrumPad.ID) -> Bool {
        return positionContinuations[padID] != nil
    }
    
    func getAllActivePadIDs() -> [AudioEngineClient.DrumPad.ID] {
        return Array(positionContinuations.keys)
    }
}
