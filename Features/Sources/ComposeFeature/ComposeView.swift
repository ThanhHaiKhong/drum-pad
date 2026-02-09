import SwiftUI
import ComposableArchitecture
import AudioEngineClient
import UIComponents

public struct ComposeView: View {
    let store: StoreOf<ComposeStore>

    public init(store: StoreOf<ComposeStore>) {
        self.store = store
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                HStack {
                    Text("Drum Pad Composer")
                        .font(.title)
                        .fontWeight(.bold)

                    Spacer()

                    Picker("Preset", selection: Binding(
                        get: { store.selectedPreset },
                        set: { preset in store.send(.loadPreset(preset)) }
                    )) {
                        Text("Select Preset").tag("")
                        Text("550").tag("550")
                        Text("Custom").tag("custom")
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                HStack {
                    Text("Current Preset: \(store.selectedPreset.isEmpty ? "None" : store.selectedPreset)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(store.audioEngineState.loadedSamplesCount)/\(store.audioEngineState.totalSamplesCount) Samples Loaded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(store.audioEngineState.pads.sorted(by: { $0.key < $1.key }), id: \.key) { padId, pad in
                        if store.audioEngineState.samples[pad.sampleId] != nil {
                            DrumPadButton(
                                pad: pad,
                                samples: store.audioEngineState.samples
                            ) { padId in
                                store.send(.playPad(padId))
                            }
                        }
                    }
                }

                HStack {
                    Button {
                        store.send(.stopAll)
                    } label: {
                        Text("Stop All")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        if !store.selectedPreset.isEmpty && store.selectedPreset != "" {
                            store.send(.loadPreset(store.selectedPreset))
                        }
                    } label: {
                        Text("Load Preset")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            }
            .fontDesign(.monospaced)
            .padding()
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
}

#Preview {
    ComposeView(
        store: Store(initialState: ComposeStore.State()) {
            ComposeStore()
        }
    )
}
