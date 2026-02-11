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
                    Text("Composer")
                        .font(.title)
                        .fontWeight(.bold)

                    Spacer()
                }

                DrumPadGridView(
                    pads: store.audioEngineState.pads,
                    samples: store.audioEngineState.samples,
                    hasRecordedSamples: [:],
                    isRecording: store.isRecording,
                    activeRecordingPadId: store.activeRecordingPadId,
                    onPadTap: { padId in
                        store.send(.playPad(padId))
                    },
                    onPadLongPress: { _ in },
                    onPadRelease: { }
                )

                HStack {
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
                            
                            Text(store.isRecording ? "Stop" : "Record")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(store.isRecording ? Color.red : Color.gray.opacity(0.2))
                        .foregroundColor(store.isRecording ? Color.white : Color.primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
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
