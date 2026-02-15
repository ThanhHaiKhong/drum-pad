//
//  DrumPadButtonStyle.swift
//  Features
//
//  Created by Thanh Hai Khong on 13/2/26.
//

import SwiftUI

public struct DrumPadButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .aspectRatio(1, contentMode: .fill)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DrumPadButtonStyle {
    @MainActor @preconcurrency
    public static var drumPad: DrumPadButtonStyle { .init() }
}
