import ComposableArchitecture

@Reducer
public struct SettingsStore: Sendable {
    @ObservableState
    public struct State: Sendable, Equatable {
        public init() { }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return handleOnAppear(state: &state)
            }
        }
    }

    public init() { }
}

extension SettingsStore {
    private func handleOnAppear(state: inout State) -> Effect<Action> {
        return .none
    }
}
