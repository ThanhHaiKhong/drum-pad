import SwiftUI
import ComposableArchitecture

public struct SettingsView: View {
    public var store: StoreOf<SettingsStore>

    public init(store: StoreOf<SettingsStore>) {
        self.store = store
    }

    public var body: some View {
        Text("SettingsView")
            .fontDesign(.monospaced)
            .onAppear {
                store.send(.onAppear)
            }
    }
}
