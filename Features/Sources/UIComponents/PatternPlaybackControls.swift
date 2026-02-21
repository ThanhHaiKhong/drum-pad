import SwiftUI
import AudioEngineClient

public struct PatternPlaybackControls: View {
    public let patternName: String
    public let tempo: Int
    public let currentStep: Int
    public let totalSteps: Int
    public let isPlaying: Bool

    public let onPlay: () -> Void
    public let onStop: () -> Void

    public init(
        patternName: String,
        tempo: Int,
        currentStep: Int,
        totalSteps: Int,
        isPlaying: Bool,
        onPlay: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self.patternName = patternName
        self.tempo = tempo
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.isPlaying = isPlaying
        self.onPlay = onPlay
        self.onStop = onStop
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Pattern info
            HStack {
                Text(patternName)
                    .font(.headline)

                Spacer()

                Text("\(tempo) BPM")
                    .font(.subheadline)
                    .monospacedDigit()
            }

            // Progress bar with step markers
            progressView

            // Current step display
            Text("Step \(currentStep + 1)/\(totalSteps)")
                .font(.caption)
                .monospacedDigit()

            // Controls
            controlButtons
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private var progressView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                    .cornerRadius(4)

                // Progress
                let progressWidth = totalSteps > 0
                    ? min(CGFloat(currentStep) / CGFloat(totalSteps) * geometry.size.width, geometry.size.width)
                    : 0

                Rectangle()
                    .fill(Color.blue)
                    .frame(width: max(0, progressWidth), height: 8)
                    .cornerRadius(4)

                // Step markers
                ForEach(Array(stride(from: 0, to: totalSteps, by: 4)), id: \.self) { step in
                    let xPos = totalSteps > 0
                        ? CGFloat(step) / CGFloat(totalSteps) * geometry.size.width
                        : 0

                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2, height: 12)
                        .position(x: xPos, y: 6)
                }
            }
        }
        .frame(height: 12)
    }

    private var controlButtons: some View {
        HStack(spacing: 20) {
            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)

            // Play button
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPlaying)
        }
    }
}

#Preview {
    PatternPlaybackControls(
        patternName: "Urban Hip-Hop",
        tempo: 90,
        currentStep: 5,
        totalSteps: 17,
        isPlaying: true,
        onPlay: {},
        onStop: {}
    )
    .padding()
}
