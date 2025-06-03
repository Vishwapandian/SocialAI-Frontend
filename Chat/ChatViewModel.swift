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
    @Published var isAITyping: Bool = false // To show typing indicator
    
    private let socialAIService = SocialAIService()
    private var cancellables = Set<AnyCancellable>()
    
    // Message queue system
    private var messageQueue: [String] = []
    private var queueTimer: Timer?
    private var isProcessingQueue: Bool = false
    
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
        isAITyping = true // Show typing indicator

        socialAIService.sendMessage(trimmedMsg)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let err) = completion {
                    self.error = err.localizedDescription
                    self.isAITyping = false
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                self.latestEmotions = response.emotions // Store emotions
                self.processAIResponse(response.response)
            }
            .store(in: &cancellables)
    }
    
    private func processAIResponse(_ response: String) {
        // Split response by newlines and filter out empty lines
        let messageParts = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Add to queue
        messageQueue.append(contentsOf: messageParts)
        
        // Start processing queue if not already processing
        if !isProcessingQueue {
            processMessageQueue()
        }
    }
    
    private func processMessageQueue() {
        guard !messageQueue.isEmpty else {
            isProcessingQueue = false
            isAITyping = false
            return
        }
        
        isProcessingQueue = true
        
        // Get the next message from queue
        let nextMessage = messageQueue.removeFirst()
        
        // Calculate delay based on character count (1 second per character, with min/max bounds)
        let characterCount = nextMessage.count
        let delay = max(1.0, min(Double(characterCount) * 0.1, 5.0)) // Min 1s, max 5s, 0.1s per char
        
        // Schedule the message to be added after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            // Add message to chat
            let aiMessage = Message(content: nextMessage, isFromUser: false)
            self.messages.append(aiMessage)
            
            // Continue processing queue
            self.processMessageQueue()
        }
    }
    
    // Stop queue processing (useful for cleanup)
    private func stopQueueProcessing() {
        queueTimer?.invalidate()
        queueTimer = nil
        messageQueue.removeAll()
        isProcessingQueue = false
        isAITyping = false
    }

    func requestEmotionDisplay() {
        if let emotions = latestEmotions, !emotions.isEmpty {
            let emotionStrings = emotions.map { "\($0.key): \($0.value)" }
            emotionDisplayContent = "Current AI Emotions:\\n" + emotionStrings.joined(separator: "\\n")
        } else {
            emotionDisplayContent = "No emotional data available yet. Send a message to see the AI's emotional state."
        }
    }

    func resetMemoryAndChat() {
        guard let currentUserId = self.userId else {
            self.error = "Cannot reset: User not identified."
            return
        }
        
        // Stop any ongoing queue processing
        stopQueueProcessing()
        
        // Call the reset API
        socialAIService.resetUserData(userId: currentUserId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let err) = completion {
                    self.error = "Failed to reset memory: \(err.localizedDescription)"
                }
            } receiveValue: { [weak self] resetResponse in
                guard let self = self else { return }
                
                if resetResponse.success {
                    // Clear local state to simulate app restart
                    self.messages = []
                    self.latestEmotions = nil
                    self.currentMessage = ""
                    self.emotionDisplayContent = nil
                    
                    print("[ChatViewModel] Reset successful - cleared local state")
                    
                    // Fetch fresh emotions (should be empty/default after reset)
                    self.fetchInitialEmotionsData()
                } else {
                    self.error = "Reset failed: \(resetResponse.message)"
                }
            }
            .store(in: &cancellables)
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
    
    deinit {
        stopQueueProcessing()
    }
}
