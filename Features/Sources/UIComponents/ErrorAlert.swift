import SwiftUI

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
