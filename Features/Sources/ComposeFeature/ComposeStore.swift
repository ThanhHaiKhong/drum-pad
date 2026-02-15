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
        public var selectedPadCount: Int = 16
        public var isRecording: Bool = false
        public var activeRecordingPadId: Int? = nil
        public var selectedTab: State.Tab = .composer
        public var drumPads: IdentifiedArrayOf<DrumPadStore.State> = []

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case loadPreset(String)
        case loadPresetResponse(TaskResult<AudioEngineClient.State>)
        case stopAll
        case stopAllResponse
        case updateAudioEngineState(AudioEngineClient.State)
        case selectPadCount(Int)
        case startRecording
        case startRecordingResponse(TaskResult<Void>)
        case stopRecording
        case stopRecordingResponse(TaskResult<String?>)
        case updateRecordingState(Bool, Int?)
        case playRecordedAudio
        case playRecordedAudioResponse(TaskResult<Void>)
        case drumPads(IdentifiedActionOf<DrumPadStore>)
    }

    @Dependency(\.audioEngine) var audioEngine

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return handleOnAppear()
                
            case .loadPreset(let presetId):
                return handleLoadPreset(state: &state, presetId: presetId)
                
            case .loadPresetResponse(.success(let newState)):
                return handleLoadPresetResponseSuccess(state: &state, newState: newState)
                
            case .loadPresetResponse(.failure(let error)):
                return handleLoadPresetResponseFailure(error: error)
                
            case .stopAll:
                return handleStopAll(state: &state)
                
            case .stopAllResponse:
                return handleStopAllResponse(state: &state)
                
            case .updateAudioEngineState(let newState):
                return handleUpdateAudioEngineState(state: &state, newState: newState)
                
            case .selectPadCount(let count):
                return handleSelectPadCount(state: &state, count: count)
                
            case .startRecording:
                return handleStartRecording()
                
            case .startRecordingResponse(.success):
                return handleStartRecordingResponseSuccess()
                
            case .startRecordingResponse(.failure(let error)):
                return handleStartRecordingResponseFailure(error: error)
                
            case .stopRecording:
                return handleStopRecording()
                
            case .stopRecordingResponse(.success(let filePath)):
                return handleStopRecordingResponseSuccess(filePath: filePath)
                
            case .stopRecordingResponse(.failure(let error)):
                return handleStopRecordingResponseFailure(error: error)
                
            case .updateRecordingState(let isRecording, let activePadId):
                return handleUpdateRecordingState(state: &state, isRecording: isRecording, activePadId: activePadId)
                
            case .playRecordedAudio:
                return handlePlayRecordedAudio()
                
            case .playRecordedAudioResponse(.success):
                return handlePlayRecordedAudioResponseSuccess()
                
            case .playRecordedAudioResponse(.failure(let error)):
                return handlePlayRecordedAudioResponseFailure(error: error)
                
            case .drumPads:
                return .none
            }
        }
        .forEach(\.drumPads, action: \.drumPads) {
            DrumPadStore()
        }
    }
    
    private func handleOnAppear() -> Effect<Action> {
        return .run { send in
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
        } catch: { error, send in
            print("Failed to initialize audio engine: \(error)")
            await send(.updateRecordingState(false, nil))
        }
    }
    
    private func handleLoadPreset(state: inout State, presetId: String) -> Effect<Action> {
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
    }
    
    private func handleLoadPresetResponseSuccess(state: inout State, newState: AudioEngineClient.State) -> Effect<Action> {
        state.audioEngineState = newState
        return .none
    }
    
    private func handleLoadPresetResponseFailure(error: Error) -> Effect<Action> {
        print("Failed to load preset: \(error)")
        return .none
    }
    
    private func handleStopAll(state: inout State) -> Effect<Action> {
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
    }
    
    private func handleStopAllResponse(state: inout State) -> Effect<Action> {
        state.isPlaying = false
        return .none
    }
    
    private func handleUpdateAudioEngineState(state: inout State, newState: AudioEngineClient.State) -> Effect<Action> {
        state.audioEngineState = newState
        var drumPadStates: [DrumPadStore.State] = []
        for sample in newState.samples {
            for pad in newState.pads {
                if pad.key == sample.key {
                    drumPadStates.append(.init(sample: sample.value, pad: pad.value))
                }
            }
        }
        state.drumPads = IdentifiedArray(uniqueElements: drumPadStates)
        return .none
    }
    
    private func handleSelectPadCount(state: inout State, count: Int) -> Effect<Action> {
        state.selectedPadCount = count
        return .none
    }
    
    // New recording action handlers
    private func handleStartRecording() -> Effect<Action> {
        return .run { send in
            let result = await TaskResult {
                try await audioEngine.startRecording()
            }

            await send(.startRecordingResponse(result))
        }
    }
    
    private func handleStartRecordingResponseSuccess() -> Effect<Action> {
        // Start monitoring recording progress
        return .run { send in
            // Monitor recording progress until it stops
            while await audioEngine.isRecording() {
                // We'll pass nil for activePadId since recording is global
                await send(.updateRecordingState(true, nil))

                // Small delay to prevent excessive updates
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            // Update final state when recording stops
            let isRecording = await audioEngine.isRecording()
            // Pass nil for activePadId since recording is global
            let activePadId: Int? = nil

            await send(.updateRecordingState(isRecording, activePadId))
        }
    }
    
    private func handleStartRecordingResponseFailure(error: Error) -> Effect<Action> {
        print("Failed to start recording: \(error)")
        return .send(.updateRecordingState(false, nil))
    }
    
    private func handleStopRecording() -> Effect<Action> {
        return .run { send in
            let result = await TaskResult {
                try await audioEngine.stopRecording()
            }

            await send(.stopRecordingResponse(result))
        }
    }
    
    private func handleStopRecordingResponseSuccess(filePath: String?) -> Effect<Action> {
        print("Recording stopped successfully, saved to: \(filePath ?? "unknown")")
        return .send(.updateRecordingState(false, nil))
    }
    
    private func handleStopRecordingResponseFailure(error: Error) -> Effect<Action> {
        print("Failed to stop recording: \(error)")
        return .send(.updateRecordingState(false, nil))
    }
    
    private func handleUpdateRecordingState(state: inout State, isRecording: Bool, activePadId: Int?) -> Effect<Action> {
        state.isRecording = isRecording
        state.activeRecordingPadId = activePadId
        return .none
    }
    
    private func handlePlayRecordedAudio() -> Effect<Action> {
        return .run { send in
            let result = await TaskResult {
                try await audioEngine.playRecordedAudio()
            }

            await send(.playRecordedAudioResponse(result))
        }
    }
    
    private func handlePlayRecordedAudioResponseSuccess() -> Effect<Action> {
        return .none
    }
    
    private func handlePlayRecordedAudioResponseFailure(error: Error) -> Effect<Action> {
        print("Failed to play recorded audio: \(error)")
        return .none
    }

    public init() {}
}

extension ComposeStore.State {
    public enum Tab: String, Identifiable, CaseIterable, Equatable, Sendable {
        case composer
        case explore
        case saved
        case settings
        
        public var id: String { self.rawValue }
    }
}
