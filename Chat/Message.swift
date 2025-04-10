//
//  Message.swift
//  Jom
//
//  Created by Vishwa Pandian on 3/29/25.
//

import Foundation
import SwiftData

@Model
final class Message {
    var content: String
    var timestamp: Date
    var isFromUser: Bool
    
    init(content: String, timestamp: Date = Date(), isFromUser: Bool) {
        self.content = content
        self.timestamp = timestamp
        self.isFromUser = isFromUser
    }
}
