//
//  DrumPadStore.swift
//  Features
//
//  Created by Thanh Hai Khong on 13/2/26.
//

import ComposableArchitecture
import AudioEngineClient
import Foundation

@Reducer
public struct DrumPadStore: Sendable {
    @ObservableState
    public struct State: Identifiable, Sendable, Equatable {
        public let id: UUID = UUID()
        public let pad: AudioEngineClient.DrumPad
        public var isPlaying: Bool = false
        public var progress: Double = 0
        
        // MARK: - Pattern Playback Support
        public var shouldHighlightForPattern: Bool = false
        public var patternHighlightScale: CGFloat = 1.0
        public var playsInCurrentPattern: Bool = false

        public init(
            pad: AudioEngineClient.DrumPad
        ) {
            self.pad = pad
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case playPad
        case updateProgress
        case setIsPlaying(Bool)
        case positionUpdates(TaskResult<AudioEngineClient.PositionUpdate>)
        
        // MARK: - Pattern Playback
        case updatePatternStep(Int, AudioEngineClient.Pattern)
        case clearPatternHighlight
        case animateHighlight
    }

    @Dependency(\.audioEngine) private var audioEngine

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .playPad:
                return handlePlayPad(state: &state)

            case .updateProgress:
                return .run { [pad = state.pad] send in
                    for await positionUpdate in await audioEngine.positionUpdates(pad.id) {
                        await send(.positionUpdates(TaskResult { positionUpdate }))
                    }
                }
                
            case .setIsPlaying(let isPlaying):
                state.isPlaying = isPlaying
                return .none
                
            case .positionUpdates(.success(let positionUpdate)):
                if positionUpdate.duration > 0 {
                    state.progress = positionUpdate.currentTime / positionUpdate.duration
                } else {
                    state.progress = 0
                }
                state.isPlaying = positionUpdate.currentTime < positionUpdate.duration
                return .none
                
            case .positionUpdates(.failure):
                state.isPlaying = false
                return .none
            
            // MARK: - Pattern Playback
            case .updatePatternStep(let currentStep, let pattern):
                // Check if this pad plays at the current step
                let playsAtStep = pattern.notes(forPadId: state.pad.id)
                    .contains { $0.start == currentStep }
                
                state.shouldHighlightForPattern = playsAtStep
                state.playsInCurrentPattern = !pattern.notes(forPadId: state.pad.id).isEmpty
                
                // Trigger animation if should highlight
                if playsAtStep {
                    return .send(.animateHighlight)
                }
                return .none
                
            case .clearPatternHighlight:
                state.shouldHighlightForPattern = false
                state.patternHighlightScale = 1.0
                return .none
                
            case .animateHighlight:
                // Pulsing animation
                state.patternHighlightScale = 1.3
                return .none
            }
        }
    }

    public init() {}
}

extension DrumPadStore {
    private func handlePlayPad(
        state: inout State
    ) -> Effect<Action> {
        return .run { [padId = state.pad.id] send in
            await send(.setIsPlaying(true))
            try await audioEngine.playPad(padId)
            await send(.updateProgress)
        } catch: { send, error in
            print("Failed to play pad: \(error)")
        }
    }
}
