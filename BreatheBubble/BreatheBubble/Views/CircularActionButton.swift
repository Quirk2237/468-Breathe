import SwiftUI

// MARK: - Circular Action Button
struct CircularActionButton: View {
    let icon: String
    let action: () -> Void
    let label: String?
    
    init(icon: String, action: @escaping () -> Void, label: String? = nil) {
        self.icon = icon
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.3))
                    .clipShape(Circle())
                
                if let label = label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: 16) {
        CircularActionButton(icon: "play.fill", action: {})
        CircularActionButton(icon: "forward.fill", action: {}, label: "Skip")
        CircularActionButton(icon: "checkmark", action: {}, label: "Done")
    }
    .padding()
    .background(.black)
}
