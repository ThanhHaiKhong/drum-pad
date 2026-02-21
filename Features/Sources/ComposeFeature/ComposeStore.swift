//
//  ComposeStore.swift
//  ComposeFeature
//
//  Created by Thanh Hai Khong on 13/2/26.
//

import ComposableArchitecture
import AudioEngineClient
import Foundation
import SequenceEngineClient
import Dependencies

@Reducer
public struct ComposeStore: Sendable {
    @ObservableState
    public struct State: Sendable {
        public var selectedPreset: String = ""
        public var isPlaying: Bool = false
        public var selectedPadCount: Int = 16
        public var isRecording: Bool = false
        public var activeRecordingPadId: Int? = nil
        public var selectedTab: State.Tab = .composer
        public var drumPads: IdentifiedArrayOf<DrumPadStore.State> = []

        // MARK: - Pattern Playback State
        public var isPatternPlaying: Bool = false
        public var currentPatternStep: Int = 0
        public var currentPatternTotalSteps: Int = 0
        public var currentPatternName: String = ""
        public var currentPatternTempo: Int = 0
        public var selectedPattern: AudioEngineClient.Pattern? = nil
        public var availablePatterns: [AudioEngineClient.Pattern] = []

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case loadPreset(String)
        case loadPresetResponse(TaskResult<AudioEngineClient.Preset>)
        case stopAll
        case stopAllResponse
        case selectPadCount(Int)
        case startRecording
        case startRecordingResponse(TaskResult<Void>)
        case stopRecording
        case stopRecordingResponse(TaskResult<String?>)
        case updateRecordingState(Bool, Int?)
        case playRecordedAudio
        case playRecordedAudioResponse(TaskResult<Void>)
        case updateDrumPads([DrumPadStore.State])

        // MARK: - Pattern Playback
        case selectPattern(AudioEngineClient.Pattern)
        case playPattern(AudioEngineClient.Pattern)
        case stopPattern
        case stopPatternResponse
        case updatePatternProgress(PatternPlaybackProgress)
        case updateAvailablePatterns([AudioEngineClient.Pattern])

        case drumPads(IdentifiedActionOf<DrumPadStore>)
    }

    @Dependency(\.audioEngine) var audioEngine
    @Dependency(\.sequenceEngine) var sequenceEngine

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return handleOnAppear()
                
            case .loadPreset(let presetId):
                return handleLoadPreset(state: &state, presetId: presetId)

            case .loadPresetResponse(.success(let preset)):
                return handleLoadPresetResponseSuccess(state: &state, preset: preset)

            case .loadPresetResponse(.failure(let error)):
                return handleLoadPresetResponseFailure(error: error)

            case .stopAll:
                return handleStopAll(state: &state)

            case .stopAllResponse:
                return handleStopAllResponse(state: &state)

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
            
            // MARK: - Pattern Playback
            case .selectPattern(let pattern):
                state.selectedPattern = pattern
                return .none
                
            case .playPattern(let pattern):
                return handlePlayPattern(state: &state, pattern: pattern)

            case .stopPattern:
                return handleStopPattern()

            case .stopPatternResponse:
                state.isPatternPlaying = false
                state.currentPatternStep = 0
                return .none

            case .updatePatternProgress(let progress):
                state.currentPatternStep = progress.currentStep
                state.currentPatternTotalSteps = progress.totalSteps
                state.currentPatternName = progress.patternName
                state.currentPatternTempo = progress.tempo
                state.isPatternPlaying = progress.isPlaying
                // Note: Pad highlighting would require broadcasting to all drum pads
                // For now, users can see the progress in the controls UI
                return .none
            
            case .updateAvailablePatterns(let patterns):
                state.availablePatterns = patterns
                return .none
            
            case .updateDrumPads(let drumPadStates):
                state.drumPads = IdentifiedArray(uniqueElements: drumPadStates)
                return .none

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
            let preset = await audioEngine.preset()
            let pads = await audioEngine.drumPads()
            
            // Load drum pads
            var drumPadStates: [DrumPadStore.State] = []
            for pad in pads {
                drumPadStates.append(DrumPadStore.State(pad: pad))
            }
            
            // Send drum pads to state
            await send(.updateDrumPads(drumPadStates))
            
            // Send available patterns and tempo
            if let patterns = preset?.beatSchool.v0, !patterns.isEmpty {
                await send(.updateAvailablePatterns(patterns))
                await send(.updatePatternProgress(
                    PatternPlaybackProgress(
                        currentStep: 0,
                        totalSteps: patterns.first?.sequencerSize ?? 0,
                        isPlaying: false,
                        patternName: patterns.first?.name ?? "",
                        tempo: preset?.tempo ?? 90
                    )
                ))
            }
        } catch: { error, send in
            print("Failed to initialize audio engine: \(error)")
            await send(.updateRecordingState(false, nil))
        }
    }
    
    private func handleLoadPreset(state: inout State, presetId: String) -> Effect<Action> {
        state.selectedPreset = presetId
        state.drumPads = []
        
        return .run { send in
            let result = await TaskResult {
                try await audioEngine.loadPreset(presetId)
                guard let preset = await audioEngine.preset() else {
                    throw NSError(domain: "Preset not found", code: 0)
                }
                return preset
            }

            await send(.loadPresetResponse(result))
        }
    }

    private func handleLoadPresetResponseSuccess(state: inout State, preset: AudioEngineClient.Preset) -> Effect<Action> {
        state.selectedPreset = preset.id
        state.currentPatternTempo = preset.tempo
        
        // Load drum pads from preset
        var drumPadStates: [DrumPadStore.State] = []
        for pad in preset.pads {
            drumPadStates.append(DrumPadStore.State(pad: pad))
        }
        state.drumPads = IdentifiedArray(uniqueElements: drumPadStates)
        
        // Populate available patterns from the preset
        if !preset.beatSchool.v0.isEmpty {
            state.availablePatterns = preset.beatSchool.v0
        }
        
        return .none
    }

    private func handleLoadPresetResponseFailure(error: Error) -> Effect<Action> {
        print("Failed to load preset: \(error)")
        return .none
    }

    private func handleStopAll(state: inout State) -> Effect<Action> {
        return .none
    }

    private func handleStopAllResponse(state: inout State) -> Effect<Action> {
        state.isPlaying = false
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
    
    // MARK: - Pattern Playback Handlers

    private func handlePlayPattern(state: inout State, pattern: AudioEngineClient.Pattern) -> Effect<Action> {
        return .run { [tempo = state.currentPatternTempo] send in
            // Set initial state
            await send(.updatePatternProgress(
                PatternPlaybackProgress(
                    currentStep: 0,
                    totalSteps: pattern.sequencerSize,
                    isPlaying: true,
                    patternName: pattern.name,
                    tempo: tempo
                )
            ))

            await sequenceEngine.playSequence(pattern, tempo, false)  // No loop

            // Listen for progress updates
            for await progress in await sequenceEngine.sequenceProgressUpdates() {
                await send(.updatePatternProgress(progress))

                if !progress.isPlaying {
                    break
                }
            }

            await send(.stopPatternResponse)
        }
    }

    private func handleStopPattern() -> Effect<Action> {
        return .run { send in
            await sequenceEngine.stopSequence()
            await send(.stopPatternResponse)
        }
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
