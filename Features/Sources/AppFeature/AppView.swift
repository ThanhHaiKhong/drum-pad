import SwiftUI
import ComposableArchitecture

public struct AppView: View {
    let store: StoreOf<AppStore>

    public init(store: StoreOf<AppStore>) {
        self.store = store
    }

    public var body: some View {
        Text("Hello, TCA!")
            .fontDesign(.monospaced)
            .onAppear {
                store.send(.onAppear)
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
