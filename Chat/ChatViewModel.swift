//
//  ChatViewModel.swift
//  ChatApp
//
//  Created by Vishwa Pandian on 3/29/25.
//

import Foundation
import SwiftData
import Combine
import SwiftUI
import FirebaseAuth

class ChatViewModel: ObservableObject {
    @Published var currentMessage: String = ""
    @Published var error: String? = nil
    
    private let socialAIService = SocialAIService()
    private var cancellables = Set<AnyCancellable>()
    
    private let modelContext: ModelContext
    @Published var currentConversation: Conversation
    
    // Inject userId from AuthViewModel if available
    var userId: String? {
        // Try to get the userId from Firebase Auth
        if let user = Auth.auth().currentUser {
            return user.uid
        }
        return nil
    }

    init(modelContext: ModelContext, conversation: Conversation? = nil) {
        self.modelContext = modelContext
        
        if let conversation = conversation {
            self.currentConversation = conversation
        } else {
            self.currentConversation = Self.fetchOrCreateTodayConversation(using: modelContext)
        }
        // Set userId for the service
        socialAIService.userId = userId
    }

    func sendMessage() {
        let trimmedMsg = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMsg.isEmpty else { return }

        let userMessage = Message(content: trimmedMsg, isFromUser: true)
        currentConversation.messages.append(userMessage)
        currentConversation.updatedAt = Date()
        try? modelContext.save()

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
                let aiMessage = Message(content: response, isFromUser: false)
                self.currentConversation.messages.append(aiMessage)
                self.currentConversation.updatedAt = Date()
                try? self.modelContext.save()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Helpers
extension ChatViewModel {
    static func fetchOrCreateTodayConversation(using context: ModelContext) -> Conversation {
        let calendar = Calendar.current
        let now = Date()
        guard
            let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        else {
            fatalError("Could not calculate start or end of day")
        }

        let fetchDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate<Conversation> {
                $0.createdAt >= startOfDay && $0.createdAt <= endOfDay
            }
        )

        do {
            let conversations = try context.fetch(fetchDescriptor)
            if let existing = conversations.first {
                return existing
            }

            let newConversation = Conversation(
                title: "Chat",
                createdAt: startOfDay,
                updatedAt: startOfDay
            )
            context.insert(newConversation)
            return newConversation
        } catch {
            print("Failed to fetch or create conversation for today: \(error)")
            let fallbackConversation = Conversation(
                title: "Chat",
                createdAt: startOfDay,
                updatedAt: startOfDay
            )
            context.insert(fallbackConversation)
            return fallbackConversation
        }
    }
}
