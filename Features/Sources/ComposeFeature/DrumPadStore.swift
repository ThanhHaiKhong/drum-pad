//
//  DrumPadStore.swift
//  Features
//
//  Created by Thanh Hai Khong on 13/2/26.
//

import ComposableArchitecture
import AudioEngineClient

@Reducer
public struct DrumPadStore: Sendable {
    @ObservableState
    public struct State: Sendable, Equatable {
        public init() {}
    }
    
    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
    }
    
    @Dependency(\.audioEngine) var audioEngine
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                return .none
            }
        }
    }
    
    public init() {}
}
