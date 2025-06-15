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
    
    // Configuration state
    @Published var customInstructions: String = "N/A"
    @Published var currentEmotions: [String: Int] = [:]
    @Published var baseEmotions: [String: Int] = [:]
    @Published var sensitivity: Int = 35  // Default - will be overwritten by loadConfiguration()
    @Published var isLoadingConfig: Bool = false
    @Published var configError: String? = nil
    
    // Personas state
    @Published var personas: [SocialAIService.Persona] = []
    @Published var selectedPersonaId: String? = nil // Applied persona id
    
    private let socialAIService = SocialAIService()
    private var cancellables = Set<AnyCancellable>()
    
    // Homeostasis emotion polling
    private var emotionPollingTimer: Timer?
    private let emotionPollingInterval: TimeInterval = 15.0 // Poll every 15 seconds to catch stochastic changes
    
    // Message queue system for AI responses
    private var messageQueue: [String] = []
    private var queueTimer: Timer?
    private var isProcessingQueue: Bool = false
    
    // Input delay system for batching user messages
    private var pendingUserMessage: String = ""
    private var inputDelayTimer: Timer?
    private var isInputDelayActive: Bool = false
    private var timerStartTime: Date?
    private var totalDelayDuration: TimeInterval = 0
    
    // Idle detection system
    private var idleTimer: Timer?
    private var isIdleTimerActive: Bool = false
    
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
        startEmotionPolling() // Start polling for homeostasis updates (includes initial fetch)
        
        // Load personas list
        loadPersonas()
    }

    func sendMessage() {
        let trimmedMsg = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMsg.isEmpty else { return }

        // Add the message to UI immediately
        let userMessage = Message(content: trimmedMsg, isFromUser: true)
        messages.append(userMessage)

        // Handle input delay and batching
        handleInputWithDelay(trimmedMsg)
        
        // Clear the current message input
        currentMessage = ""
        
        // Start idle detection since input is now empty
        startIdleTimer()
    }
    
    // New function to handle when the input text changes
    func onMessageInputChanged() {
        if currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Input is empty, start idle timer if we have pending messages
            if isInputDelayActive && !pendingUserMessage.isEmpty {
                startIdleTimer()
            }
        } else {
            // User is typing, stop idle timer
            stopIdleTimer()
        }
    }
    
    private func handleInputWithDelay(_ message: String) {
        let characterCount = message.count
        let additionalDelayInSeconds = max(20.0, Double(characterCount * 1)) // Minimum 20 seconds, 1 second per character
        
        if isInputDelayActive {
            // Timer is already running, calculate remaining time and use max with new delay
            guard let startTime = timerStartTime else {
                // Fallback if start time is somehow nil
                pendingUserMessage = message
                isInputDelayActive = true
                timerStartTime = Date()
                totalDelayDuration = additionalDelayInSeconds
                startNewTimer(duration: additionalDelayInSeconds)
                return
            }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            let remainingTime = max(0, totalDelayDuration - elapsedTime)
            
            // Concatenate the message
            if !pendingUserMessage.isEmpty {
                pendingUserMessage += "\n" + message
            } else {
                pendingUserMessage = message
            }
            
            // Cancel existing timer
            inputDelayTimer?.invalidate()
            
            // Use the maximum of remaining time and new message delay
            let newTotalDuration = max(remainingTime, additionalDelayInSeconds)
            totalDelayDuration = newTotalDuration
            timerStartTime = Date() // Reset start time to now
            
            // Start new timer with the calculated duration
            startNewTimer(duration: newTotalDuration)
        } else {
            // No timer running, start a new batch
            pendingUserMessage = message
            isInputDelayActive = true
            timerStartTime = Date()
            totalDelayDuration = additionalDelayInSeconds
            
            startNewTimer(duration: additionalDelayInSeconds)
        }
    }
    
    private func startNewTimer(duration: TimeInterval) {
        inputDelayTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.sendBatchedMessage()
        }
    }
    
    private func sendBatchedMessage() {
        guard !pendingUserMessage.isEmpty else {
            resetInputDelay()
            return
        }
        
        let messageToSend = pendingUserMessage
        resetInputDelay()
        
        // Set typing indicator
        isAITyping = true
        
        // Send the batched message to the backend
        socialAIService.sendMessage(messageToSend)
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
    
    private func resetInputDelay() {
        inputDelayTimer?.invalidate()
        inputDelayTimer = nil
        pendingUserMessage = ""
        isInputDelayActive = false
        timerStartTime = nil
        totalDelayDuration = 0
        stopIdleTimer()
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
        
        // Stop any ongoing processing
        stopQueueProcessing()
        resetInputDelay()
        
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
                    
                    // Restart emotion polling to get fresh emotions (should be empty/default after reset)
                    self.startEmotionPolling()
                    
                    // Refetch personas to get the new default set
                    self.loadPersonas()
                } else {
                    self.error = "Reset failed: \(resetResponse.message)"
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stopQueueProcessing()
        resetInputDelay()
        stopEmotionPolling()
    }

    private func startIdleTimer() {
        // Only start idle timer if we have pending messages and no idle timer is running
        guard isInputDelayActive && !pendingUserMessage.isEmpty && !isIdleTimerActive else { return }
        
        isIdleTimerActive = true
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.handleIdleTimeout()
        }
    }
    
    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
        isIdleTimerActive = false
    }
    
    private func handleIdleTimeout() {
        // User has been idle for 5 seconds, send the batched message immediately
        stopIdleTimer()
        
        // Cancel the main delay timer and send immediately
        inputDelayTimer?.invalidate()
        sendBatchedMessage()
    }

    private func startEmotionPolling() {
        guard let currentUserId = self.userId else {
            print("[ChatViewModel] Cannot start emotion polling: userId is nil.")
            return
        }
        
        // Stop any existing timer
        stopEmotionPolling()
        
        print("[ChatViewModel] Starting emotion polling every \(emotionPollingInterval) seconds")
        
        // Immediately fetch emotions once, then start the regular timer
        pollForEmotionUpdates()
        
        emotionPollingTimer = Timer.scheduledTimer(withTimeInterval: emotionPollingInterval, repeats: true) { [weak self] _ in
            self?.pollForEmotionUpdates()
        }
    }
    
    private func stopEmotionPolling() {
        emotionPollingTimer?.invalidate()
        emotionPollingTimer = nil
        print("[ChatViewModel] Stopped emotion polling")
    }
    
    private func pollForEmotionUpdates() {
        guard let currentUserId = self.userId else {
            print("[ChatViewModel] Cannot poll emotions: userId is nil.")
            return
        }
        
        socialAIService.fetchCurrentEmotions(userId: currentUserId)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    // Silently handle polling errors to avoid spamming the user
                    print("[ChatViewModel] Emotion polling failed: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] emotionResponse in
                // Only update if emotions have actually changed
                if self?.latestEmotions != emotionResponse.emotions {
                    print("[ChatViewModel] Homeostasis emotion update: \(emotionResponse.emotions)")
                    self?.latestEmotions = emotionResponse.emotions
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    
    func pauseEmotionPolling() {
        print("[ChatViewModel] Pausing emotion polling")
        stopEmotionPolling()
    }
    
    func resumeEmotionPolling() {
        print("[ChatViewModel] Resuming emotion polling")
        startEmotionPolling()
    }
    
    // MARK: - Configuration Management
    
    func loadConfiguration() {
        guard let currentUserId = self.userId else {
            configError = "Cannot load configuration: User not identified."
            return
        }
        
        isLoadingConfig = true
        configError = nil
        
        socialAIService.getAllConfiguration(userId: currentUserId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isLoadingConfig = false
                if case .failure(let error) = completion {
                    self.configError = "Failed to load configuration: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] config in
                guard let self = self else { return }
                self.currentEmotions = config.emotions
                self.baseEmotions = config.baseEmotions
                self.sensitivity = config.sensitivity
                self.customInstructions = config.customInstructions
            }
            .store(in: &cancellables)
    }
    
    func updateBaseEmotions(_ newBaseEmotions: [String: Int]) {
        guard let currentUserId = self.userId else {
            configError = "Cannot update emotions: User not identified."
            return
        }
        
        // Validate emotions sum to 100
        let total = newBaseEmotions.values.reduce(0, +)
        guard total == 100 else {
            configError = "Emotions must sum to 100. Current total: \(total)"
            return
        }
        
        isLoadingConfig = true
        configError = nil
        
        // Update only base emotions, not current emotions
        socialAIService.updateBaseEmotions(userId: currentUserId, baseEmotions: newBaseEmotions)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isLoadingConfig = false
                if case .failure(let error) = completion {
                    self.configError = "Failed to update base emotions: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if response.success {
                    self.baseEmotions = newBaseEmotions
                } else {
                    self.configError = "Failed to update base emotions: \(response.message)"
                }
            }
            .store(in: &cancellables)
    }
    
    func updateSensitivity(_ newSensitivity: Int) {
        guard let currentUserId = self.userId else {
            configError = "Cannot update sensitivity: User not identified."
            return
        }
        
        // Validate sensitivity is between 0 and 100
        guard 0...100 ~= newSensitivity else {
            configError = "Sensitivity must be between 0 and 100. Current value: \(newSensitivity)"
            return
        }
        
        isLoadingConfig = true
        configError = nil
        
        socialAIService.updateSensitivity(userId: currentUserId, sensitivity: newSensitivity)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isLoadingConfig = false
                if case .failure(let error) = completion {
                    self.configError = "Failed to update sensitivity: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if response.success {
                    self.sensitivity = newSensitivity
                } else {
                    self.configError = "Failed to update sensitivity: \(response.message)"
                }
            }
            .store(in: &cancellables)
    }
    
    func updateCustomInstructions(_ newInstructions: String) {
        guard let currentUserId = self.userId else {
            configError = "Cannot update custom instructions: User not identified."
            return
        }
        
        isLoadingConfig = true
        configError = nil
        
        socialAIService.updateCustomInstructions(userId: currentUserId, customInstructions: newInstructions)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isLoadingConfig = false
                if case .failure(let error) = completion {
                    self.configError = "Failed to update custom instructions: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if response.success {
                    self.customInstructions = newInstructions
                } else {
                    self.configError = "Failed to update custom instructions: \(response.message)"
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Personas CRUD

    func loadPersonas() {
        guard userId != nil else { return }
        socialAIService.fetchPersonas()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let err) = completion {
                    print("[ChatViewModel] Failed to load personas: \(err.localizedDescription)")
                }
            } receiveValue: { [weak self] personas in
                guard let self = self else { return }
                let sorted = personas.sorted(by: ChatViewModel.sortByRecent)
                withAnimation {
                    self.personas = sorted
                }
            }
            .store(in: &cancellables)
    }

    func createPersona(named name: String = "New Persona", completion: ((SocialAIService.Persona) -> Void)? = nil) {
        guard userId != nil else { return }
        socialAIService.createPersona(name: name)
            .receive(on: DispatchQueue.main)
            .sink { completionSink in
                if case .failure(let err) = completionSink {
                    print("[ChatViewModel] Failed to create persona: \(err.localizedDescription)")
                }
            } receiveValue: { [weak self] persona in
                if let self = self {
                    withAnimation {
                        self.personas.append(persona)
                        self.personas.sort(by: ChatViewModel.sortByRecent)
                    }
                    completion?(persona)
                }
            }
            .store(in: &cancellables)
    }

    func updatePersona(_ persona: SocialAIService.Persona) {
        guard userId != nil else { return }
        socialAIService.updatePersona(persona)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let err) = completion {
                    print("[ChatViewModel] Failed to update persona: \(err.localizedDescription)")
                }
            } receiveValue: { [weak self] updated in
                guard let self = self else { return }
                if let idx = self.personas.firstIndex(where: { $0.id == updated.id }) {
                    self.personas[idx] = updated
                }
                // Resort list to ensure most recently used stays on top
                withAnimation {
                    self.personas.sort(by: ChatViewModel.sortByRecent)
                }
            }
            .store(in: &cancellables)
    }

    func deletePersona(personaId: String, completion: (() -> Void)? = nil) {
        guard userId != nil else { return }
        socialAIService.deletePersona(personaId: personaId)
            .receive(on: DispatchQueue.main)
            .sink { completionSink in
                if case .failure(let err) = completionSink {
                    print("[ChatViewModel] Failed to delete persona: \(err.localizedDescription)")
                }
            } receiveValue: { [weak self] success in
                guard success else { return }
                self?.personas.removeAll { $0.id == personaId }
                completion?()
            }
            .store(in: &cancellables)
    }

    // Apply persona values to user configuration endpoints
    func applyPersona(_ persona: SocialAIService.Persona) {
        guard let currentUserId = self.userId else {
            configError = "Cannot apply persona: user not identified."
            return
        }

        // Apply base emotions first
        updateBaseEmotions(persona.baseEmotions)
        // Then sensitivity
        updateSensitivity(persona.sensitivity)
        // Then custom instructions
        updateCustomInstructions(persona.customInstructions)

        // Mark persona as last used (update timestamp)
        var updatedPersona = persona
        let isoString = ISO8601DateFormatter().string(from: Date())
        updatedPersona.lastUsed = isoString
        updatePersona(updatedPersona)

        // Save selection locally
        selectedPersonaId = persona.id

        // Resort personas list locally as well
        withAnimation {
            personas.sort(by: ChatViewModel.sortByRecent)
        }
    }

    // Helper static for sorting personas by lastUsed desc
    private static func sortByRecent(_ p1: SocialAIService.Persona, _ p2: SocialAIService.Persona) -> Bool {
        let formatter = ISO8601DateFormatter()
        let d1 = p1.lastUsed.flatMap { formatter.date(from: $0) } ?? Date.distantPast
        let d2 = p2.lastUsed.flatMap { formatter.date(from: $0) } ?? Date.distantPast
        return d1 > d2
    }
}
