//
//  ChatViewModel.swift
//  ChatApp
//
//  Created by Vishwa Pandian on 3/29/25.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth

class ChatViewModel: ObservableObject {
    @Published var currentMessage: String = ""
    @Published var error: String? = nil
    @Published var latestEmotions: [String: Int]? = nil // To store the latest emotions
    @Published var emotionDisplayContent: String? = nil // For the alert
    @Published var messages: [Message] = []
    
    private let socialAIService = SocialAIService()
    private var cancellables = Set<AnyCancellable>()
    
    // Inject userId from AuthViewModel if available
    var userId: String? {
        // Try to get the userId from Firebase Auth
        if let user = Auth.auth().currentUser {
            return user.uid
        }
        return nil
    }

    init() {
        // Set userId for the service
        socialAIService.userId = userId
        // Initialize an empty chat
        self.messages = []
        fetchInitialEmotionsData() // Fetch emotions from backend
    }

    func sendMessage() {
        let trimmedMsg = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMsg.isEmpty else { return }

        let userMessage = Message(content: trimmedMsg, isFromUser: true)
        messages.append(userMessage)

        currentMessage = ""

        socialAIService.sendMessage(trimmedMsg)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let err) = completion {
                    self.error = err.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                let aiMessage = Message(content: response.response, isFromUser: false)
                self.messages.append(aiMessage)
                self.latestEmotions = response.emotions // Store emotions
            }
            .store(in: &cancellables)
    }

    func requestEmotionDisplay() {
        if let emotions = latestEmotions, !emotions.isEmpty {
            let emotionStrings = emotions.map { "\($0.key): \($0.value)" }
            emotionDisplayContent = "Current AI Emotions:\\n" + emotionStrings.joined(separator: "\\n")
        } else {
            emotionDisplayContent = "No emotional data available yet. Send a message to see the AI's emotional state."
        }
    }

    private func fetchInitialEmotionsData() {
        guard let currentUserId = self.userId else {
            print("[ChatViewModel] Cannot fetch initial emotions: userId is nil.")
            // Optionally, set emotionDisplayContent to an error or guidance message here
            // self.emotionDisplayContent = "Could not fetch AI emotions: User not identified."
            return
        }

        socialAIService.fetchInitialEmotions(userId: currentUserId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let err) = completion {
                    print("[ChatViewModel] Failed to fetch initial emotions: \(err.localizedDescription)")
                    // self?.error = "Failed to load initial AI mood: \(err.localizedDescription)"
                    // Consider setting emotionDisplayContent to provide feedback
                     self?.emotionDisplayContent = "Could not load AI's current mood. Please try again later."
                }
            } receiveValue: { [weak self] emotionResponse in
                print("[ChatViewModel] Successfully fetched initial emotions: \(emotionResponse.emotions)")
                self?.latestEmotions = emotionResponse.emotions
                // If you want to immediately show emotions in the alert after fetching:
                // self?.requestEmotionDisplay() 
            }
            .store(in: &cancellables)
    }
}
