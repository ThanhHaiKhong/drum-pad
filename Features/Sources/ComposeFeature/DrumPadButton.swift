//
//  DrumPadButton.swift
//  Features
//
//  Created by Thanh Hai Khong on 11/2/26.
//

import AudioEngineClient
import Dependencies
import SwiftUI

public struct DrumPadButton: View {
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.0
    
    let pad: AudioEngineClient.DrumPad
    let samples: [Int: AudioEngineClient.Sample]
    let hasRecordedSample: Bool
    let isRecording: Bool
    let onTap: (Int) -> Void
    let onLongPress: (Int) -> Void
    let onRelease: () -> Void
    
    @Dependency(\.audioEngine) var audioEngine: AudioEngineClient

    public init(
        pad: AudioEngineClient.DrumPad,
        samples: [Int: AudioEngineClient.Sample],
        hasRecordedSample: Bool,
        isRecording: Bool,
        onTap: @escaping (Int) -> Void,
        onLongPress: @escaping (Int) -> Void,
        onRelease: @escaping () -> Void
    ) {
        self.pad = pad
        self.samples = samples
        self.hasRecordedSample = hasRecordedSample
        self.isRecording = isRecording
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onRelease = onRelease
    }

    public var body: some View {
        ZStack {
            Button {
                onTap(pad.id)
                startPlaybackAnimation()
            } label: {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(hex: pad.color) ?? .gray)
                    .overlay {
                        if let sample = samples[pad.sampleId] {
                            Text(sample.name.prefix(2).uppercased())
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .minimumScaleFactor(0.5)
                        }
                        
                        Circle()
                            .trim(from: 0.0, to: isPlaying ? progress : 0.0)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [.white, Color(hex: pad.color) ?? .gray]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .square, lineJoin: .bevel)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                            .opacity(isPlaying ? 1.0 : 0.0)
                    }
            }
            .buttonStyle(DrumPadButtonStyle())
            
            if hasRecordedSample {
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .position(x: 20, y: 20)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onEnded { _ in
                    onLongPress(pad.id)
                }
        )
        .onLongPressGesture(
            minimumDuration: 0.1,
            maximumDistance: 100,
            perform: {
                onLongPress(pad.id)
            },
            onPressingChanged: { pressing in
                if !pressing {
                    onRelease()
                }
            }
        )
    }
    
    private func startPlaybackAnimation() {
        isPlaying = true
        progress = 0.0

        // Get the sample associated with this pad
        if let sample = samples[pad.sampleId] {
            // Use the actual duration of the sample if available
            Task {
                do {
                    let duration = try await audioEngine.sampleDuration(sample.path)
                    
                    // Animate the progress ring based on the sample's actual duration
                    await MainActor.run {
                        withAnimation(.linear(duration: duration)) {
                            progress = 1.0
                        }
                        
                        // Reset after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isPlaying = false
                            }
                        }
                    }
                } catch {
                    // Fallback to default animation if duration retrieval fails
                    let defaultDuration = 1.0
                    await MainActor.run {
                        withAnimation(.linear(duration: defaultDuration)) {
                            progress = 1.0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + defaultDuration) {
                            withAnimation {
                                isPlaying = false
                            }
                        }
                    }
                }
            }
        } else {
            // Fallback to default animation if sample is not found
            let defaultDuration = 1.0
            withAnimation(.linear(duration: defaultDuration)) {
                progress = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + defaultDuration) {
                withAnimation {
                    isPlaying = false
                }
            }
        }
    }
}

public struct DrumPadButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .aspectRatio(1, contentMode: .fill)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        switch hexSanitized.lowercased() {
        case "red":
            self = .red
            return
        case "blue":
            self = .blue
            return
        case "green":
            self = .green
            return
        case "yellow":
            self = .yellow
            return
        case "orange":
            self = .orange
            return
        case "purple":
            self = .purple
            return
        case "pink":
            self = .pink
            return
        case "brown":
            self = .brown
            return
        case "cyan":
            self = .cyan
            return
        case "gray", "grey":
            self = .gray
            return
        case "black":
            self = .black
            return
        case "white":
            self = .white
            return
        case "mint":
            self = .mint
            return
        case "teal":
            self = .teal
            return
        case "indigo":
            self = .indigo
            return
        default:
            break
        }

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
