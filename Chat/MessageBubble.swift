//
//  MessageBubble.swift
//  Jom
//
//  Created by Vishwa Pandian on 3/29/25.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.isFromUser ? Color("birdieBlue") : Color("birdieBackground"))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(16)
                    .textSelection(.enabled)

                if message.isFromUser {
                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack {
        MessageBubble(message: Message(content: "Hello, how can I help you today?", isFromUser: false))
        MessageBubble(message: Message(content: "I need help with SwiftUI", isFromUser: true))
    }
}
