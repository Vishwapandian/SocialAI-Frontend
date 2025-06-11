import SwiftUI

struct RedAuraPreview: View {
    var body: some View {
        ZStack {
            
            RadialGradient(
                gradient: Gradient(colors: [.red, .red.opacity(0.8), .red.opacity(0.4), .clear]),
                center: .center,
                startRadius: 50,
                endRadius: 100
            )
            .blur(radius: 60) // Soften the edges for an aura effect
            .ignoresSafeArea() // Make the background fill the entire screen
            
            RadialGradient(
                gradient: Gradient(colors: [.yellow, .yellow.opacity(0.8), .yellow.opacity(0.4), .clear]),
                center: .center,
                startRadius: 25,
                endRadius: 250
            )
            .blur(radius: 60) // Soften the edges for an aura effect
            .ignoresSafeArea() // Make the background fill the entire screen
        }
    }
}

#Preview {
    RedAuraPreview()
}
