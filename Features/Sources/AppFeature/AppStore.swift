import ComposableArchitecture
import SwiftUI
import ComposeFeature
import DiscoverFeature
import LibraryFeature
import SettingsFeature

@Reducer
public struct AppStore: Sendable {
    @ObservableState
    public struct State: Sendable, Equatable {
        var compose = ComposeStore.State()
        var discover = DiscoverStore.State()
        var library = LibraryStore.State()
        var settings = SettingsStore.State()
        
        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case compose(ComposeStore.Action)
        case discover(DiscoverStore.Action)
        case library(LibraryStore.Action)
        case settings(SettingsStore.Action)
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            case .compose:
                return .none
            case .discover:
                return .none
            case .library:
                return .none
            case .settings:
                return .none
            }
        }
        
        Scope(state: \.compose, action: \.compose) {
            ComposeStore()
        }
        
        Scope(state: \.discover, action: \.discover) {
            DiscoverStore()
        }
        
        Scope(state: \.library, action: \.library) {
            LibraryStore()
        }
        
        Scope(state: \.settings, action: \.settings) {
            SettingsStore()
        }
    }

    public init() {}
}
