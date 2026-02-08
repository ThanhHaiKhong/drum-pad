import ComposableArchitecture
import SwiftUI

@Reducer
public struct AppStore: Sendable {
    @ObservableState
    public struct State: Sendable, Equatable {
        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }

    public init() {}
}
