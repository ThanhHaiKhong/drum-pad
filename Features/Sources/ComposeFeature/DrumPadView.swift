//
//  DrumPadView.swift
//  Features
//
//  Created by Thanh Hai Khong on 11/2/26.
//

import ComposableArchitecture
import SwiftUI

public struct DrumPadView: View {
    private var store: StoreOf<DrumPadStore>
    private var padColor: Color {
        Color(hex: store.pad.color) ?? .gray
    }

    public init(
        store: StoreOf<DrumPadStore>
    ) {
        self.store = store
    }

    public var body: some View {
        Button {
            store.send(.playPad)
        } label: {
            ZStack {
                Rectangle()
                    .fill(padColor)
                    .brightness(store.shouldHighlightForPattern ? 0.3 : 0)
                
                // Pulsing effect for pattern playback
                if store.shouldHighlightForPattern {
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        .scaleEffect(store.patternHighlightScale)
                        .animation(.easeOut(duration: 0.2), value: store.patternHighlightScale)
                }
            }
            .overlay(alignment: .top) {
                VStack(alignment: .leading) {
                    CustomProgressView(progress: store.progress)

                    Spacer()

                    Text(store.pad.sample.name.prefix(2).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(10)
            }
        }
        .buttonStyle(.drumPad)
    }
}
