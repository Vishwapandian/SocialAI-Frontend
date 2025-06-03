import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isLoading = false

    // State variable to hold the current set of colors for the gradient
    @State private var gradientColors: [Color] = Self.generateRandomColors()
    // State variable to control the animation
    @State private var animateGradient = false

    // The main colors for the aura
    static let auraColors: [Color] = [.yellow, .blue, .purple, .green, .red]

    // Timer to change the colors periodically
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
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

            // Your existing content
            VStack(spacing: 24) {
                
                Spacer()
                
                // Apple Sign-In Button
                Button {
                    handleAppleSignIn()
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.title2)
                            .frame(width: 20, height: 20)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                        Text("Continue with Apple ")
                            //.fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                }

                // Google Sign-In Button
                Button {
                    handleGoogleSignIn()
                } label: {
                    HStack {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                        Text("Continue with Google")
                            //.fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                }

                // Error message
                if let error = auth.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .padding()
        .background(.ultraThinMaterial)
        .onTapGesture {
            dismissKeyboard()
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

    // MARK: - Helpers

    private func handleGoogleSignIn() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return }
        Task {
            await auth.signInWithGoogle(presentingVC: root)
        }
    }

    private func handleAppleSignIn() {
        auth.signInWithApple()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

        // To make the gradient more dynamic, sometimes we might want to repeat colors
        // or ensure the start and end points are different.
        // For simplicity, we're just taking a random slice.
        // You can add more sophisticated logic here for color combinations.

        // Ensure there are at least two colors for a gradient
        if colorsToShow.count < 2 {
            colorsToShow.append(auraColors.randomElement() ?? .clear) // Fallback color
            if colorsToShow.count < 2 { // If still less than 2 (e.g. auraColors was empty or had 1 element)
                 colorsToShow.append(auraColors.randomElement() ?? .black) // Another fallback
            }
        }
        return colorsToShow
    }
}

// Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthViewModel())
    }
}
