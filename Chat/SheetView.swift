import SwiftUI

struct SheetView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var auth: AuthViewModel
    
    // State variable to hold the current set of colors for the gradient
    @State private var gradientColors: [Color] = Self.generateRandomColors()
    // State variable to control the animation
    @State private var animateGradient = false
    // State for reset confirmation alert
    @State private var showingResetConfirmation = false

    // The main colors for the aura
    static let auraColors: [Color] = [.yellow, .blue, .purple, .green, .red]

    // Timer to change the colors periodically
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ZStack {
                // The fluctuating aura background
                RadialGradient(
                    gradient: Gradient(colors: gradientColors),
                    center: .center,
                    startRadius: 50,
                    endRadius: 500 // Adjust for desired spread
                )
                .blur(radius: 60) // Soften the edges for an aura effect
                .animation(.easeInOut(duration: 2), value: animateGradient) // Animate color changes
                .ignoresSafeArea() // Make the background fill the entire screen
                
                Text("This is a placeholder sheet view.")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.requestEmotionDisplay()
                    } label: {
                        Image(systemName: "brain.fill")
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sign out", role: .destructive) { auth.signOut() }
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                    }
                }
            }
            .alert("Reset Memory", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetMemoryAndChat()
                }
            } message: {
                Text("Are you sure you want to reset all your data? This will clear the AI's memory of your conversations and emotional state. This action cannot be undone.")
            }
            .onReceive(timer) { _ in
                // Trigger a new set of random colors and the animation
                self.gradientColors = Self.generateRandomColors()
                self.animateGradient.toggle()
            }
            .onAppear {
                // Initial animation trigger
                self.animateGradient.toggle()
            }
        }
    }
    
    // Function to generate a random subset and order of aura colors
    static func generateRandomColors() -> [Color] {
        // Shuffle the main aura colors
        var shuffledColors = auraColors.shuffled()
        // Take a random number of colors (at least 2 for a gradient)
        let numberOfColors = Int.random(in: 2...shuffledColors.count)
        // Ensure we have distinct colors for the start and end of the base gradient
        // and add more random colors in between if needed.
        var colorsToShow = Array(shuffledColors.prefix(numberOfColors))

        // Ensure there are at least two colors for a gradient
        if colorsToShow.count < 2 {
            colorsToShow.append(auraColors.randomElement() ?? .clear) // Fallback color
            if colorsToShow.count < 2 { // If still less than 2
                 colorsToShow.append(auraColors.randomElement() ?? .black) // Another fallback
            }
        }
        return colorsToShow
    }
}

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        SheetView(viewModel: ChatViewModel())
            .environmentObject(AuthViewModel())
    }
} 