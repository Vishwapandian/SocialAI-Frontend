//
//  MessageBubble.swift
//  Jom
//
//  Created by Vishwa Pandian on 3/29/25.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    @State private var isVisible = false
    @State private var hasAppeared = false
    
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
        .scaleEffect(isVisible ? 1.0 : 0.85)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: isVisible)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                // Add a small delay for staggered effect when multiple messages load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isVisible = true
                    }
                }
            } else {
                isVisible = true
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Typing Indicator Component
struct TypingIndicator: View {
    @State private var currentDot = 0
    @State private var isVisible = false
    @State private var timer: Timer?
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(currentDot == index ? 1.3 : 0.8)
                        .opacity(currentDot == index ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.3),
                            value: currentDot
                        )
                }
            }
            .frame(minHeight: 20)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .scaleEffect(isVisible ? 1.0 : 0.85)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            // Add entrance animation for typing indicator
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            
            // Start the dot animation cycle
            startDotAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = false
            }
        }
    }
    
    private func startDotAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentDot = (currentDot + 1) % 3
            }
        }
    }
}

#Preview {
    VStack {
        MessageBubble(message: Message(content: "Hello, how can I help you today?", isFromUser: false))
        MessageBubble(message: Message(content: "I need help with SwiftUI", isFromUser: true))
    }
}
