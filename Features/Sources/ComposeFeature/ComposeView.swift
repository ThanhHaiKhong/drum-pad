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
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 20) {
                // Header with preset selection
                HStack {
                    Text("Drum Pad Composer")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Preset selector
                    Picker("Preset", selection: viewStore.binding(
                        get: { $0.selectedPreset.isEmpty ? "Select Preset" : $0.selectedPreset },
                        send: { .loadPreset($0) }
                    )) {
                        Text("Select Preset").tag("Select Preset")
                        Text("550").tag("550")
                        Text("Custom").tag("custom")
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding()
                
                // Current preset info
                HStack {
                    Text("Current Preset: \(viewStore.audioEngineState.currentPreset.isEmpty ? "None" : viewStore.audioEngineState.currentPreset)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(viewStore.audioEngineState.loadedSamplesCount)/\(viewStore.audioEngineState.totalSamplesCount) Samples Loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Drum pad grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(viewStore.audioEngineState.pads.sorted(by: { $0.key < $1.key }), id: \.key) { padId, pad in
                        if viewStore.audioEngineState.samples[pad.sampleId] != nil {
                            DrumPadButton(
                                pad: pad,
                                samples: viewStore.audioEngineState.samples
                            ) { padId in
                                viewStore.send(.playPad(padId))
                            }
                            .frame(height: 80)
                        } else {
                            // Empty pad if no sample assigned
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Text("Empty")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                )
                                .frame(height: 80)
                        }
                    }
                }
                .padding()
                
                // Controls
                HStack {
                    Button("Stop All") {
                        viewStore.send(.stopAll)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Load Preset") {
                        if !viewStore.selectedPreset.isEmpty && viewStore.selectedPreset != "Select Preset" {
                            viewStore.send(.loadPreset(viewStore.selectedPreset))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .onAppear {
                viewStore.send(.onAppear)
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