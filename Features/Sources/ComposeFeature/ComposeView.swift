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

                // Recording indicator
                if store.isRecording {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Recording...")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.bottom, 10)
                }

                // Drum pad grid (for playing sounds)
                DrumPadGridView(
                    pads: store.audioEngineState.pads,
                    samples: store.audioEngineState.samples,
                    hasRecordedSamples: [:], // Will need to update this when we have recorded samples in state
                    isRecording: store.isRecording,
                    activeRecordingPadId: store.activeRecordingPadId,
                    onPadTap: { padId in
                        // Play the pad regardless of recording state
                        store.send(.playPad(padId))
                    },
                    onPadLongPress: { _ in },
                    onPadRelease: { }
                )

                HStack {
                    Button {
                        store.send(.stopAll)
                    } label: {
                        Text("Stop All")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    // Record button to start/stop recording
                    Button {
                        if store.isRecording {
                            store.send(.stopRecording)
                        } else {
                            store.send(.startRecording)
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(store.isRecording ? Color.white : Color.red)
                                .frame(width: 10, height: 10)
                                .padding(5)
                            Text(store.isRecording ? "Stop Recording" : "Start Recording")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(store.isRecording ? Color.red : Color.gray.opacity(0.2))
                        .foregroundColor(store.isRecording ? Color.white : Color.primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.borderless)
                    
                    // Play recorded audio button
                    Button {
                        store.send(.playRecordedAudio)
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                            Text("Play Recorded")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(Color.primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.borderless)

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
