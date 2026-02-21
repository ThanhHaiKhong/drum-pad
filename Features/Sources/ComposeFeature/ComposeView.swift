//
//  ComposeView.swift
//  ComposeFeature
//
//  Created by Thanh Hai Khong on 13/2/26.
//

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
        ScrollView {
            VStack(spacing: 16) {
                // Pattern selection section
                patternSelectionSection
                
                // Pattern playback controls (show when pattern is selected)
                if store.selectedPattern != nil {
                    PatternPlaybackControls(
                        patternName: store.currentPatternName,
                        tempo: store.currentPatternTempo,
                        currentStep: store.currentPatternStep,
                        totalSteps: store.currentPatternTotalSteps,
                        isPlaying: store.isPatternPlaying,
                        onPlay: {
                            if let pattern = store.selectedPattern {
                                store.send(.playPattern(pattern))
                            }
                        },
                        onStop: {
                            store.send(.stopPattern)
                        }
                    )
                }
                
                // Drum pads grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.scope(state: \.drumPads, action: \.drumPads)) { store in
                        DrumPadView(store: store)
                    }
                }
                .padding(.horizontal)
                
                // Recording controls - hide when pattern is playing
                if !store.isPatternPlaying {
                    recordSection
                }
            }
            .padding(.vertical)
        }
        .fontDesign(.monospaced)
        .onAppear {
            store.send(.onAppear)
        }
    }
}

extension ComposeView {
    /// Pattern selection section with available BeatSchool patterns
    public var patternSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "music.note.list")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("BeatSchool Patterns")
                    .font(.headline)
                
                Spacer()
                
                if !store.availablePatterns.isEmpty {
                    Text("\(store.availablePatterns.count) patterns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if store.availablePatterns.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No patterns available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Make sure a preset with BeatSchool patterns is loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.availablePatterns) { pattern in
                            PatternButton(
                                pattern: pattern,
                                isSelected: store.selectedPattern?.id == pattern.id,
                                tempo: store.currentPatternTempo,
                                onSelect: {
                                    store.send(.selectPattern(pattern))
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    public var practiceSection: some View {
        HStack {
            Button {

            } label: {
                Text("Practice")
                    .font(.headline)
                    .fontDesign(.monospaced)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
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

// MARK: - Pattern Button Component

/// A button component for selecting and displaying pattern info
struct PatternButton: View {
    let pattern: AudioEngineClient.Pattern
    let isSelected: Bool
    let tempo: Int
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Header with name and checkmark
                HStack {
                    Text(pattern.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .bold : .semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                // Pattern info
                HStack(spacing: 6) {
                    Label("\(pattern.sequencerSize)", systemImage: "list.bullet")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Label("\(tempo)", systemImage: "metronome")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                // Steps indicator
                HStack(spacing: 2) {
                    ForEach(0..<min(pattern.sequencerSize, 16), id: \.self) { index in
                        Rectangle()
                            .fill(index < pattern.sequencerSize ? Color.secondary.opacity(0.3) : Color.clear)
                            .frame(width: 3, height: 3)
                            .cornerRadius(1)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .frame(width: 170, height: 90)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

#Preview {
    ComposeView(
        store: Store(initialState: ComposeStore.State()) {
            ComposeStore()
        }
    )
}
