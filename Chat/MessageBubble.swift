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
                    .background(.ultraThinMaterial)
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                    .textSelection(.enabled)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
            }
            if !message.isFromUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Typing Indicator Component
struct TypingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    VStack {
        MessageBubble(message: Message(content: "Hello, how can I help you today?", isFromUser: false))
        MessageBubble(message: Message(content: "I need help with SwiftUI", isFromUser: true))
    }
}
