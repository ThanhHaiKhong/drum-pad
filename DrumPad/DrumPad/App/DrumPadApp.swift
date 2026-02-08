import SwiftUI
import ComposableArchitecture
import AppFeature

@main
struct DrumPadApp: App {
    let store = Store(initialState: AppStore.State()) {
        AppStore()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
