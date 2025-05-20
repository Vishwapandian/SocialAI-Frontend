//
//  Message.swift
//  Jom
//
//  Created by Vishwa Pandian on 3/29/25.
//

import Foundation

/// A simple in-memory chat message model
struct Message: Identifiable, Equatable {
    let id = UUID()
    var content: String
    var timestamp: Date
    var isFromUser: Bool
    
    init(content: String, timestamp: Date = Date(), isFromUser: Bool) {
        self.content = content
        self.timestamp = timestamp
        self.isFromUser = isFromUser
    }
}
