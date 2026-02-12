//
//  DrumPadGridView.swift
//  Features
//
//  Created by Thanh Hai Khong on 11/2/26.
//

import AudioEngineClient
import SwiftUI

public struct DrumPadGridView: View {
    let pads: [Int: AudioEngineClient.DrumPad]
    let samples: [Int: AudioEngineClient.Sample]
    let hasRecordedSamples: [Int: Bool] // Dictionary indicating which pads have recorded samples
    let isRecording: Bool
    let activeRecordingPadId: Int?
    let onPadTap: (Int) -> Void
    let onPadLongPress: (Int) -> Void
    let onPadRelease: () -> Void

    public init(
        pads: [Int: AudioEngineClient.DrumPad],
        samples: [Int: AudioEngineClient.Sample],
        hasRecordedSamples: [Int: Bool],
        isRecording: Bool,
        activeRecordingPadId: Int?, // Still keeping this for potential future use
        onPadTap: @escaping (Int) -> Void,
        onPadLongPress: @escaping (Int) -> Void,
        onPadRelease: @escaping () -> Void
    ) {
        self.pads = pads
        self.samples = samples
        self.hasRecordedSamples = hasRecordedSamples
        self.isRecording = isRecording
        self.activeRecordingPadId = activeRecordingPadId
        self.onPadTap = onPadTap
        self.onPadLongPress = onPadLongPress
        self.onPadRelease = onPadRelease
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(Array(pads.sorted(by: { $0.key < $1.key }).map { $0.value }), id: \.id) { pad in
                DrumPadButton(
                    pad: pad,
                    samples: samples,
                    hasRecordedSample: hasRecordedSamples[pad.id] ?? false,
                    isRecording: isRecording,
                    onTap: onPadTap,
                    onLongPress: onPadLongPress,
                    onRelease: onPadRelease
                )
            }
        }
    }
}
