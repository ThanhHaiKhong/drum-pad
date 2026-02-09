import SwiftUI
import ComposableArchitecture
import ComposeFeature

public struct AppView: View {
    let store: StoreOf<AppStore>

    public init(store: StoreOf<AppStore>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ComposeView(
                store: store.scope(state: \.composeState, action: \.compose)
            )
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppStore.State()) {
            AppStore()
        }
    )
}
