//
//  KnowledgeUpdateService.swift
//  Jom
//
//  Created by Vishwa Pandian on 4/9/25.
//

import Foundation
import SwiftData
import Combine
import BackgroundTasks
import UIKit

class KnowledgeUpdateService: ObservableObject {
    private let geminiService = GeminiService()
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    private let backgroundTaskIdentifier = "com.Chat.knowledgeUpdate"
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Create initial knowledge.txt file if it doesn't exist
        ensureKnowledgeFileExists()
        
        // Register background task
        registerBackgroundTask()
        
        // Schedule initial background task
        scheduleKnowledgeUpdate()
        
        // Add notification observer for app going to background
        setupBackgroundingObserver()
    }
    
    // Update model context if needed
    func updateModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // Register background task
    private func registerBackgroundTask() {
        // Register for background processing
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { [weak self] task in
            guard let self = self else {
                task.setTaskCompleted(success: false)
                return
            }
            
            print("Background task triggered for knowledge update")
            
            // Create a task to track for expiration
            let taskComplete = task.expirationHandler == nil
            
            // Set up expiration handler
            task.expirationHandler = {
                self.cancellables.forEach { $0.cancel() }
                if !taskComplete {
                    print("Background task expired before completion")
                }
            }
            
            // Perform the update
            self.performKnowledgeUpdate { success in
                task.setTaskCompleted(success: success)
                self.scheduleKnowledgeUpdate()
            }
        }
        print("Registered background task: \(backgroundTaskIdentifier)")
    }
    
    // Schedule the background task for knowledge update
    func scheduleKnowledgeUpdate() {
        // Cancel any existing scheduled tasks with this identifier
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        
        // Calculate time for next 11:59 PM
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 23
        dateComponents.minute = 59
        dateComponents.second = 0
        
        guard let scheduledTime = calendar.date(from: dateComponents) else { return }
        
        let now = Date()
        var timeInterval = scheduledTime.timeIntervalSince(now)
        
        // If today's 11:59 PM has already passed, schedule for tomorrow
        if timeInterval < 0 {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: scheduledTime) {
                timeInterval = nextDay.timeIntervalSince(now)
            }
        }
        
        // Set earliest begin date to run at 11:59 PM
        request.earliestBeginDate = Date(timeIntervalSinceNow: timeInterval)
        
        // Add a grace period to allow task to run if device was asleep
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled for knowledge update at: \(request.earliestBeginDate?.description ?? "unknown time")")
        } catch {
            print("Could not schedule background task: \(error.localizedDescription)")
        }
    }
    
    // Perform the knowledge update and call completion when done
    private func performKnowledgeUpdate(completion: @escaping (Bool) -> Void) {
        guard let modelContext = modelContext else {
            print("No model context available for knowledge update")
            completion(false)
            return
        }
        
        // Get today's conversation
        let today = Date()
        let todayConversation = ChatViewModel.fetchOrCreateTodayConversation(using: modelContext)
        
        // Read current knowledge.txt
        let knowledgeFilePath = getKnowledgeFilePath()
        var currentKnowledge = ""
        
        if FileManager.default.fileExists(atPath: knowledgeFilePath.path) {
            do {
                currentKnowledge = try String(contentsOf: knowledgeFilePath, encoding: .utf8)
            } catch {
                print("Error reading knowledge.txt: \(error.localizedDescription)")
            }
        }
        
        // Format today's chat history
        let messagesFormatted = formatChatHistory(messages: todayConversation.messages)
        
        // Get formatted date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let todayDateString = dateFormatter.string(from: today)
        
        // Create prompt for Gemini
        let prompt = """
        \(todayDateString)'s chat: \(messagesFormatted)

        Current Knowledge: \(currentKnowledge)
        
        Output only the FULL updated memories. Separate each “memory” by a comma.
        """
        
        // Send to Gemini to update knowledge
        geminiService.sendMessageWithSystemPrompt(prompt, systemPrompt: "You are an AI that forms, updates, and deletes memories about a user. You will receive a chat dialog between an AI and a human user. You will also receive the current saved memories. Your job is to update these memories based on the chat. Make sure to save important details about the user that may be helpful for future chats. Output only the FULL updated memories. Separate each “memory” by a comma.")
            .receive(on: DispatchQueue.main)
            .sink { completionResult in
                if case .failure(let error) = completionResult {
                    print("Error updating knowledge: \(error.localizedDescription)")
                    completion(false)
                }
            } receiveValue: { [weak self] response in
                // Save updated knowledge to knowledge.txt
                self?.saveKnowledge(knowledge: response)
                print("Successfully updated knowledge")
                completion(true)
            }
            .store(in: &cancellables)
    }
    
    // Format chat history as a readable string
    private func formatChatHistory(messages: [Message]) -> String {
        var formattedChat = ""
        
        for message in messages {
            let role = message.isFromUser ? "User" : "AI"
            formattedChat += "\(role): \(message.content)\n"
        }
        
        return formattedChat
    }
    
    // Save knowledge to knowledge.txt
    private func saveKnowledge(knowledge: String) {
        let knowledgeFilePath = getKnowledgeFilePath()
        
        do {
            try knowledge.write(to: knowledgeFilePath, atomically: true, encoding: .utf8)
            print("Knowledge updated successfully at \(knowledgeFilePath)")
        } catch {
            print("Failed to save knowledge: \(error.localizedDescription)")
        }
    }
    
    // Get path to knowledge.txt file
    private func getKnowledgeFilePath() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("knowledge.txt")
    }
    
    // Make sure knowledge.txt exists in the documents directory
    private func ensureKnowledgeFileExists() {
        let knowledgeFilePath = getKnowledgeFilePath()
        
        if !FileManager.default.fileExists(atPath: knowledgeFilePath.path) {
            // Check if we have a bundled knowledge.txt to copy from
            if let bundlePath = Bundle.main.path(forResource: "knowledge", ofType: "txt"),
               let initialContent = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
                try? initialContent.write(to: knowledgeFilePath, atomically: true, encoding: .utf8)
            } else {
                // Create an empty knowledge file with initial CSV format if no bundled file
                let initialContent = "name, \n" // Starting with minimal content
                try? initialContent.write(to: knowledgeFilePath, atomically: true, encoding: .utf8)
            }
            print("Created initial knowledge.txt at \(knowledgeFilePath)")
        }
    }
    
    // Setup observer for app going to background - this gives us one more chance to update knowledge
    private func setupBackgroundingObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBackgrounding),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    // When app is backgrounding, try to do a final knowledge update
    @objc private func appBackgrounding() {
        print("App backgrounding - updating knowledge")
        triggerManualUpdate()
    }
    
    // Manually trigger a knowledge update - can be called when user closes the app
    func triggerManualUpdate() {
        // Do a quick check if we have any meaningful data before starting update
        guard let modelContext = modelContext else { return }
        let conversation = ChatViewModel.fetchOrCreateTodayConversation(using: modelContext)
        
        if !conversation.messages.isEmpty {
            performKnowledgeUpdate { success in
                print("Manual knowledge update completed with success: \(success)")
            }
        }
    }
}
