//
//  ChatApp.swift
//  ChatApp
//
//  Created by Vishwa Pandian on 3/29/25.
//

import SwiftUI
import SwiftData
import Combine
import UserNotifications
import BackgroundTasks
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

// Extension to provide an empty ModelContainer for initialization
extension ModelContainer {
    static var empty: ModelContainer {
        do {
            let schema = Schema([])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create empty ModelContainer: \(error)")
        }
    }
}

@main
struct ChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            Message.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AuthGate()
                .environmentObject(authVM)
                .modelContainer(sharedModelContainer)
                .onAppear { UITableView.appearance().backgroundColor = .clear }
        }
    }
}

/// AuthGate: swap between AuthView and the real app once logged in
private struct AuthGate: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.user != nil {
            // ✅ already signed in – show the chat UI
            ContentView()
        } else {
            // 🔒 not signed in
            AuthView()
        }
    }
}

// App Delegate to handle notifications
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
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    /// Handle the Google Sign-In redirect back into the app
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
