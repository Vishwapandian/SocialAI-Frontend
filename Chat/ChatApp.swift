import SwiftUI
import Combine
import UserNotifications
import BackgroundTasks
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@main
struct ChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // ⚠️  Inject the shared SocialAIService so we can end‑chat on background / terminate.
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var socialAIService = SocialAIService()

    // Scene‑phase observer (just in case)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AuthGate()
                .environmentObject(authVM)
                .environmentObject(socialAIService)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
                .onChange(of: scenePhase) { old, newPhase in
                    switch newPhase {
                    case .background:
                        print("[ChatApp] Scene moved to BACKGROUND – sending end‑chat")
                        socialAIService.endChat()
                    case .inactive:
                        print("[ChatApp] Scene became INACTIVE – (no network call)")
                    case .active:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}

/// AuthGate: swap between AuthView and the real app once logged in
private struct AuthGate: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.isLoading {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if auth.user != nil {
            // ✅ already signed in – show the chat UI
            ContentView()
        } else {
            // 🔒 not signed in
            AuthView()
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // ▶️ 1. Firebase
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        return true
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("[ChatApp] Notification permission granted")
            } else if let error = error {
                print("[ChatApp] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    /// Handle the Google Sign‑In redirect back into the app
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // 🔔 Fire end‑chat when the app is backgrounded (e.g. user swipes up to quit)
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("[ChatApp] applicationDidEnterBackground – sending end‑chat")
        SocialAIService().endChat()
    }

    // 🔔 Fire end‑chat as a final safety when the app is about to terminate
    func applicationWillTerminate(_ application: UIApplication) {
        print("[ChatApp] applicationWillTerminate – sending end‑chat")
        SocialAIService().endChat()
    }

    // -------------------------------------------------------------
    // UNUserNotificationCenterDelegate stubs
    // -------------------------------------------------------------
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
