import SwiftUI
import ComposableArchitecture

public struct DiscoverView: View {
    public var store: StoreOf<DiscoverStore>

    public init(store: StoreOf<DiscoverStore>) {
        self.store = store
    }

    public var body: some View {
        Text("DiscoverView")
            .fontDesign(.monospaced)
            .onAppear {
                store.send(.onAppear)
            }
    }
}
