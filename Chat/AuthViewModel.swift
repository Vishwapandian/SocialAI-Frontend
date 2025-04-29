import Foundation
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FirebaseCore
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

    // Public bindings
    @Published var user: User?
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var error: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        // Monitor auth state
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    // MARK: - Email / password

    func signUpWithEmail() async {
        do {
            let _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signInWithEmail() async {
        do {
            let _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - Google

    func signInWithGoogle(presentingVC: UIViewController) async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.error = "Missing Google Client ID"
            return
        }

        // one-liner config from the plist
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            // 1️⃣ present the Google sheet
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)

            // 1️⃣ unwrap and check tokens
            guard
                let idToken = result.user.idToken?.tokenString,
                !idToken.isEmpty
            else {
                throw URLError(.badServerResponse)
            }
            let accessToken = result.user.accessToken.tokenString
            guard !accessToken.isEmpty else {
                throw URLError(.badServerResponse)
            }

            // 3️⃣ build the Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: accessToken)

            // 4️⃣ sign in
            let _ = try await Auth.auth().signIn(with: credential)
        } catch {
            self.error = error.localizedDescription
        }
    }
} 
