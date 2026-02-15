import SwiftUI
import ComposableArchitecture
import AudioEngineClient
import UIComponents

public struct ComposeView: View {
    private let store: StoreOf<ComposeStore>
    private var columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 4
    )

    public init(
        store: StoreOf<ComposeStore>
    ) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(store.scope(state: \.drumPads, action: \.drumPads)) { store in
                    DrumPadView(store: store)
                }
            }
            .padding(.horizontal)
        }
        .fontDesign(.monospaced)
        .onAppear {
            store.send(.onAppear)
        }
    }
}

extension ComposeView {
    public var headerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(ComposeStore.State.Tab.allCases) { tab in
                    Button {
                        
                    } label: {
                        Text(tab.rawValue)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(store.selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    public var padSelection: some View {
        HStack {
            Text("Pads:")
                .font(.headline)

            Spacer()

            ForEach([8, 12, 16], id: \.self) { count in
                Button {
                    store.send(.selectPadCount(count))
                } label: {
                    Text("\(count)")
                        .font(.headline)
                        .frame(width: 40, height: 34)
                        .background(
                            count == store.selectedPadCount
                                ? Color.blue
                                : Color.gray.opacity(0.2)
                        )
                        .foregroundColor(
                            count == store.selectedPadCount
                                ? Color.white
                                : Color.primary
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.bottom, 10)
    }
    
    public var recordSection: some View {
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
}

#Preview {
    ComposeView(
        store: Store(initialState: ComposeStore.State()) {
            ComposeStore()
        }
    )
}
