import SwiftUI
import AudioEngineClient

// Reusable UI components go here


/// A drum pad button that plays a sound when tapped
public struct DrumPadButton: View {
    let pad: AudioEngineClient.DrumPad
    let samples: [Int: AudioEngineClient.Sample]
    let onTap: (Int) -> Void

    public init(pad: AudioEngineClient.DrumPad, samples: [Int: AudioEngineClient.Sample], onTap: @escaping (Int) -> Void) {
        self.pad = pad
        self.samples = samples
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: {
            onTap(pad.id)
        }) {
            ZStack {
                Circle()
                    .fill(Color(hex: pad.color) ?? .gray)
                    .opacity(0.8)
                    .shadow(radius: 5)
                
                if let sample = samples[pad.sampleId] {
                    Text(sample.name.prefix(2).uppercased())
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(DrumPadButtonStyle())
    }
}

/// Custom button style for drum pads
public struct DrumPadButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 70, height: 70)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Grid view to display drum pads in a grid
public struct DrumPadGridView: View {
    let pads: [Int: AudioEngineClient.DrumPad]
    let samples: [Int: AudioEngineClient.Sample]
    let onPadTap: (Int) -> Void

    public init(pads: [Int: AudioEngineClient.DrumPad], samples: [Int: AudioEngineClient.Sample], onPadTap: @escaping (Int) -> Void) {
        self.pads = pads
        self.samples = samples
        self.onPadTap = onPadTap
    }
    
    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(Array(pads.sorted(by: { $0.key < $1.key }).map { $0.value }), id: \.id) { pad in
                DrumPadButton(
                    pad: pad,
                    samples: samples
                ) { padId in
                    onPadTap(padId)
                }
            }
        }
        .padding()
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

// Extension to create UIColor from hex string
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
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
