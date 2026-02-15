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
            Rectangle()
                .fill(padColor)
                .overlay(alignment: .top) {
                    VStack(alignment: .leading) {
                        CustomProgressView(progress: store.progress)
                            .frame(height: 4)
                            .opacity(store.isPlaying ? 1.0 : 0.0)
                        
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
