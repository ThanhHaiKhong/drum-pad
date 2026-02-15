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
        public let sample: AudioEngineClient.Sample
        public let pad: AudioEngineClient.DrumPad
        public var isPlaying: Bool = false
        public var progress: Double = 0
        
        public init(
            sample: AudioEngineClient.Sample,
            pad: AudioEngineClient.DrumPad
        ) {
            self.sample = sample
            self.pad = pad
        }
    }
    
    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case playPad
    }
    
    @Dependency(\.audioEngine) private var audioEngine
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .playPad:
                return handlePlayPad(state: &state)
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
            try await audioEngine.playPad(padId)
        } catch: { send, error in
            
        }
    }
}
