//
//  DrumPadItemView.swift
//  Features
//
//  Created by Thanh Hai Khong on 11/2/26.
//

import AudioEngineClient
import Dependencies
import SwiftUI

public struct DrumPadItemView: View {
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
        Button {
            onTap(pad.id)
            startPlaybackAnimation()
        } label: {
            Rectangle()
                .fill(Color(hex: pad.color) ?? .gray)
                .overlay(alignment: .top) {
                    VStack(alignment: .leading) {
                        CustomProgressView(progress: progress)
                            .frame(height: 4)
                            .opacity(isPlaying ? 1.0 : 0.0)
                        
                        Spacer()
                        
                        if let sample = samples[pad.sampleId] {
                            Text(sample.name.prefix(2).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .padding(10)
                }
        }
        .buttonStyle(DrumPadButtonStyle())
    }
    
    private func startPlaybackAnimation() {
        isPlaying = true
        progress = 0.0
        
        // Get the sample associated with this pad
        if let sample = samples[pad.sampleId] {
            // Use the actual duration of the sample if available
            Task {
                let duration = (try? await audioEngine.sampleDuration(sample.path)) ?? 1.0
                
                // Update progress in real-time based on actual playback
                await updateProgress(duration: duration)
            }
        } else {
            // Fallback to default animation if sample is not found
            Task {
                await updateProgress(duration: 1.0)
            }
        }
    }
    
    private func updateProgress(duration: Double) async {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(duration)
        
        // Update progress in small increments for smooth animation
        let updateInterval: TimeInterval = 0.05 // Update every 50ms
        var nextUpdateTime = startTime.addingTimeInterval(updateInterval)
        
        while Date() < endTime && isPlaying {
            let elapsed = Date().timeIntervalSince(startTime)
            let currentProgress = min(elapsed / duration, 1.0)
            
            await MainActor.run {
                progress = currentProgress
            }
            
            // Wait until next update time
            let currentTime = Date()
            if currentTime < nextUpdateTime {
                let sleepTime = nextUpdateTime.timeIntervalSince(currentTime)
                try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
            }
            
            nextUpdateTime = nextUpdateTime.addingTimeInterval(updateInterval)
        }
        
        // Ensure we reach 100% and reset properly
        await MainActor.run {
            progress = 1.0
        }
        
        // Small delay before resetting to ensure animation completes
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        await MainActor.run {
            withAnimation {
                isPlaying = false
                progress = 0.0
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

struct CustomProgressView: View {
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: 4)
                    .foregroundColor(.black.opacity(0.125))
                
                Rectangle()
                    .frame(width: min(progress * geometry.size.width, geometry.size.width), height: 4)
                    .foregroundColor(.white)
            }
        }
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
