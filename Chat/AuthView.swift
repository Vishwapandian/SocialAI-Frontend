import SwiftUI
import GoogleSignInSwift

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isNewAccount = false
    @State private var isLoading = false
    @State private var confirmPassword = ""

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            // Birdie Image
            Image("birdie")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.top, 24)

            // Title
            Text(isNewAccount ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(primaryTextColor)

            // Email
            inputField(title: "Email", text: $auth.email, isSecure: false)

            // Password
            inputField(title: "Password", text: $auth.password, isSecure: true)

            // Confirm Password (only in sign-up mode)
            if isNewAccount {
                inputField(title: "Confirm Password", text: $confirmPassword, isSecure: true)
            }

            // Primary Action Button
            Button(action: handleAuthAction) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isNewAccount ? "Sign Up" : "Sign In")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(primaryButtonColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading || (isNewAccount && auth.password != confirmPassword))

            // Divider
            dividerWithText("or")

            // Google Sign-In Button (custom styled container)
            Button {
                handleGoogleSignIn()
            } label: {
                HStack {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(primaryTextColor)
                .cornerRadius(12)
            }
            .frame(height: 50)

            // Switch between Sign In / Sign Up
            Button(action: {
                withAnimation(.none) {
                    isNewAccount.toggle()
                    auth.error = nil
                }
            }) {
                Text(isNewAccount ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.footnote)
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.top, 8)

            // Error message
            if let error = auth.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ?
                UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0) :
                UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
        }))
        .onTapGesture {
            dismissKeyboard()
        }
    }

    // MARK: - Helpers

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(.systemGroupedBackground)
    }

    private var primaryButtonColor = Color("birdieblue")

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.gray : Color.gray
    }

    private func inputField(title: String, text: Binding<String>, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(title, text: text)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                    .autocapitalization(.none)
            } else {
                TextField(title, text: text)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
            }
        }
    }

    private func dividerWithText(_ text: String) -> some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .opacity(0.3)
            Text(text)
                .foregroundColor(.gray)
                .font(.caption)
            Rectangle()
                .frame(height: 1)
                .opacity(0.3)
        }
    }

    private func handleAuthAction() {
        Task {
            isLoading = true
            defer { isLoading = false }

            if isNewAccount {
                if auth.password == confirmPassword {
                    await auth.signUpWithEmail()
                } else {
                    auth.error = "Passwords do not match."
                }
            } else {
                await auth.signInWithEmail()
            }
        }
    }

    private func handleGoogleSignIn() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return }
        Task {
            await auth.signInWithGoogle(presentingVC: root)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Preview
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthViewModel())
    }
}
