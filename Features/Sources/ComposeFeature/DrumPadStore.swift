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
