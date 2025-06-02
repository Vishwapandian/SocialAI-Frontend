import SwiftUI

struct MessageInputView: View {
    @Binding var message: String
    var onSend: () -> Void
    @Binding var isFocused: Bool
    @FocusState private var isFocusedInternal: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            TextField("Talk with EV-0", text: $message, axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                //.background(Color.gray.opacity(0.2))  // Translucent gray background
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isFocusedInternal)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                        Color.gray.opacity(0.4) :  // Translucent gray for disabled state
                        Color.white)       // Original active color
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
            }
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 8)
        .onChange(of: isFocusedInternal) { oldValue, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { oldValue, newValue in
            if isFocusedInternal != newValue {
                isFocusedInternal = newValue
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    let dx = value.predictedEndLocation.x - value.location.x
                    let dy = value.predictedEndLocation.y - value.location.y
                    guard abs(dy) > abs(dx) else { return }  // only vertical swipes
                    if dy < -100 && !isFocusedInternal {
                        isFocusedInternal = true
                    } else if dy > 100 && isFocusedInternal {
                        isFocusedInternal = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
        )
    }
}

// --- Helper Extensions ---
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
