import ComposableArchitecture
import AudioEngineClient
import Foundation

@Reducer
public struct ComposeStore: Sendable {
    @ObservableState
    public struct State: Sendable, Equatable {
        public var audioEngineState: AudioEngineClient.State = .init()
        public var selectedPreset: String = ""
        public var isPlaying: Bool = false
        
        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case loadPreset(String)
        case loadPresetResponse(TaskResult<AudioEngineClient.State>)
        case playPad(Int)
        case playPadResponse(TaskResult<Void>)
        case stopAll
        case stopAllResponse
        case updateAudioEngineState(AudioEngineClient.State)
    }

    @Dependency(\.audioEngine) var audioEngine

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    // Initialize the audio engine
                    do {
                        // Try to load the default preset
                        try await audioEngine.loadPreset("550")
                        
                        let samples = await audioEngine.loadedSamples()
                        let pads = await audioEngine.drumPads()
                        let currentPresetId = await audioEngine.currentPresetId()

                        var newState = AudioEngineClient.State()
                        newState.samples = samples
                        newState.pads = pads
                        newState.currentPreset = currentPresetId ?? ""
                        newState.loadedSamplesCount = samples.count
                        newState.totalSamplesCount = pads.count

                        await send(.updateAudioEngineState(newState))
                    } catch {
                        print("Failed to initialize audio engine: \(error)")
                    }
                }
                
            case .loadPreset(let presetId):
                return .run { send in
                    var newState = AudioEngineClient.State()
                    newState.samples = [:]
                    newState.pads = [:]
                    newState.currentPreset = presetId
                    newState.loadedSamplesCount = 0
                    newState.totalSamplesCount = 0
                    
                    await send(.updateAudioEngineState(newState))
                    
                    let result = await TaskResult {
                        try await audioEngine.loadPreset(presetId)
                        
                        let samples = await audioEngine.loadedSamples()
                        let pads = await audioEngine.drumPads()
                        
                        var updatedState = AudioEngineClient.State()
                        updatedState.samples = samples
                        updatedState.pads = pads
                        updatedState.currentPreset = presetId
                        updatedState.loadedSamplesCount = samples.count
                        updatedState.totalSamplesCount = pads.count
                        
                        return updatedState
                    }
                    
                    await send(.loadPresetResponse(result))
                }
                
            case .loadPresetResponse(.success(let newState)):
                state.audioEngineState = newState
                return .none
                
            case .loadPresetResponse(.failure(let error)):
                print("Failed to load preset: \(error)")
                return .none
                
            case .playPad(let padId):
                return .run { send in
                    let result = await TaskResult {
                        try await audioEngine.playPad(padId)
                    }
                    
                    await send(.playPadResponse(result))
                }
                
            case .playPadResponse(.success):
                state.isPlaying = true
                return .none
                
            case .playPadResponse(.failure(let error)):
                print("Failed to play pad: \(error)")
                return .none
                
            case .stopAll:
                let currentState = state.audioEngineState
                return .run { send in
                    await audioEngine.stopAll()
                    
                    var newState = AudioEngineClient.State()
                    newState.samples = currentState.samples
                    newState.pads = currentState.pads
                    newState.currentPreset = currentState.currentPreset
                    newState.loadedSamplesCount = currentState.loadedSamplesCount
                    newState.totalSamplesCount = currentState.totalSamplesCount
                    newState.isPlaying = false
                    
                    await send(.updateAudioEngineState(newState))
                }
                
            case .stopAllResponse:
                state.isPlaying = false
                return .none
                
            case .updateAudioEngineState(let newState):
                state.audioEngineState = newState
                return .none
            }
        }
    }

    public init() {}
}