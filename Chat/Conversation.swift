//
//  Conversation.swift
//  ChatApp
//
//  Created by Vishwa Pandian on 3/29/25.
//

import Foundation
import SwiftData

@Model
final class Conversation {
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var messages: [Message] = []

    init(title: String = "New Chat", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
