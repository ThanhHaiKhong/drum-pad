import SwiftUI
import ComposableArchitecture

public struct LibraryView: View {
    public var store: StoreOf<LibraryStore>

    public init(store: StoreOf<LibraryStore>) {
        self.store = store
    }

    public var body: some View {
        Text("LibraryView")
            .fontDesign(.monospaced)
            .onAppear {
                store.send(.onAppear)
            }
    }
}
