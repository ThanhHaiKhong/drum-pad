import SwiftUI
import AudioEngineClient
import Dependencies

public struct DrumPadButton: View {
    let pad: AudioEngineClient.DrumPad
    let samples: [Int: AudioEngineClient.Sample]
    let hasRecordedSample: Bool
    let isRecording: Bool
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.0
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
                ZStack {
                    // Background rectangle with color
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: pad.color) ?? .gray)
                        .opacity(0.8)
                    
                    // Overlay with sample name
                    if let sample = samples[pad.sampleId] {
                        Text(sample.name.prefix(2).uppercased())
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.5)
                    }
                }
                .overlay(
                    // Progress ring around the button
                    Circle()
                        .trim(from: 0.0, to: isPlaying ? progress : 0.0)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.white, Color(hex: pad.color) ?? .gray]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                        .offset(x: 0, y: 0)
                )
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
                // Perform action when long press completes
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

/// Custom button style for drum pads
public struct DrumPadButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .aspectRatio(1, contentMode: .fill)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Grid view to display drum pads in a grid
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

/// Loading indicator view
public struct LoadingView: View {
    let isLoading: Bool
    let message: String
    
    public init(isLoading: Bool, message: String = "Loading...") {
        self.isLoading = isLoading
        self.message = message
    }
    
    public var body: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text(message)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .foregroundColor(.white)
        }
    }
}

/// Error alert view
public struct ErrorAlert: View {
    @Binding var errorMessage: String?
    let onDismiss: () -> Void
    
    public init(errorMessage: Binding<String?>, onDismiss: @escaping () -> Void) {
        self._errorMessage = errorMessage
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        if let message = errorMessage {
            VStack {
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.red)
                Text(message)
                    .multilineTextAlignment(.center)
                Button("OK") {
                    onDismiss()
                }
                .padding(.top)
            }
            .padding()
            .frame(maxWidth: 300)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red, lineWidth: 2)
            )
        }
    }
}

// Extension to create Color from hex string or named color
extension Color {
    init?(hex: String) {
        // First, try to parse as hex
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        // If it's a named color, convert to corresponding Color
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

        // If not a named color, try parsing as hex
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
