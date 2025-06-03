import SwiftUI

struct RedAuraPreview: View {
    var body: some View {
        ZStack {
            
            RadialGradient(
                gradient: Gradient(colors: [.red, .red.opacity(0.8), .red.opacity(0.4), .clear]),
                center: .center,
                startRadius: 50,
                endRadius: 500
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
        .background(
            LinearGradient(
                            gradient: Gradient(colors: [
                                // Custom color for black (R:0, G:0, B:0)
                                Color(red: 31/255, green: 31/255, blue: 31/255),
                                // Custom color for white (R:255, G:255, B:255)
                                Color(red: 7/255, green: 7/255, blue: 7/255)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
        )
    }
}

#Preview {
    RedAuraPreview()
}
