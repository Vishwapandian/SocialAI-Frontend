import SwiftUI
import GoogleSignInSwift       // 🔥 pre-made Google button

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isNewAccount = false        // toggle between sign-in and sign-up
    @State private var isLoading    = false

    var body: some View {
        VStack(spacing: 24) {
            Text(isNewAccount ? "Create account" : "Welcome back")
                .font(.largeTitle).bold()

            TextField("E-mail", text: $auth.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(.gray.opacity(0.15))
                .cornerRadius(12)

            SecureField("Password", text: $auth.password)
                .textContentType(.password)
                .padding()
                .background(.gray.opacity(0.15))
                .cornerRadius(12)

            Button {
                Task {
                    isLoading = true
                    if isNewAccount {
                        await auth.signUpWithEmail()
                    } else {
                        await auth.signInWithEmail()
                    }
                    isLoading = false
                }
            } label: {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text(isNewAccount ? "Sign up with E-mail" : "Sign in with E-mail")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 61/255, green: 107/255, blue: 171/255))
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading)

            // Divider
            HStack { Rectangle().frame(height: 1).opacity(0.3)
                Text("or").opacity(0.5)
                Rectangle().frame(height: 1).opacity(0.3) }

            // Google Sign-In button
            GoogleSignInButton {
                guard let root = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                        .first?.rootViewController else { return }
                Task { await auth.signInWithGoogle(presentingVC: root) }
            }
            .frame(height: 50)

            Button(isNewAccount ? "Already have an account? Sign in" :
                                   "Don't have an account? Sign up") {
                isNewAccount.toggle()
            }
            .font(.footnote)
            .padding(.top, 8)

            if let error = auth.error {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            Spacer()
        }
        .padding()
    }
} 
