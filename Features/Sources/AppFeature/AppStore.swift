import ComposableArchitecture
import SwiftUI
import ComposeFeature

@Reducer
public struct AppStore: Sendable {
    @ObservableState
    public struct State: Sendable, Equatable {
        var composeState = ComposeStore.State()
        
        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case compose(ComposeStore.Action)
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.composeState, action: \.compose) {
            ComposeStore()
        }
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            case .compose:
                return .none
            }
        }
    }

    public init() {}
}
