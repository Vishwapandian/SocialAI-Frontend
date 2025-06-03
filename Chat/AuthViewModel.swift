import Foundation
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FirebaseCore
import SwiftUI
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: NSObject, ObservableObject {

    // Public bindings
    @Published var user: User?
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var error: String?
    @Published var isLoading: Bool = true

    private var handle: AuthStateDidChangeListenerHandle?
    
    // For Apple Sign-In
    private var currentNonce: String?

    override init() {
        super.init()
        // Monitor auth state
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isLoading = false
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
    
    // MARK: - Apple Sign-In
    
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - Apple Sign-In Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                self.error = "Unable to fetch identity token"
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                self.error = "Unable to serialize token string from data"
                return
            }
            
            // Initialize a Firebase credential
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                    idToken: idTokenString,
                                                    rawNonce: nonce)
            
            // Sign in with Firebase
            Task {
                do {
                    let _ = try await Auth.auth().signIn(with: credential)
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error with more specific messaging
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                self.error = "Apple Sign-In was canceled"
            case .failed:
                self.error = "Apple Sign-In failed. Please try again."
            case .invalidResponse:
                self.error = "Invalid response from Apple Sign-In"
            case .notHandled:
                self.error = "Apple Sign-In was not handled"
            case .unknown:
                self.error = "Unknown Apple Sign-In error occurred"
            @unknown default:
                self.error = "Apple Sign-In error: \(error.localizedDescription)"
            }
        } else {
            self.error = "Apple Sign-In error: \(error.localizedDescription)"
        }
        print("[AuthViewModel] Apple Sign-In error: \(error)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
} 
