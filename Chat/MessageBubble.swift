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
    let latestEmotions: [String: Int]?

    // Animation speed based on emotion intensity (higher intensity = faster typing)
    private let baseSpeed: TimeInterval = 0.5  // Base speed for neutral emotions
    private let minSpeed: TimeInterval = 0.15  // Fastest speed (high intensity)
    private let maxSpeed: TimeInterval = 0.8   // Slowest speed (low intensity)

    // Stores the currently active animation interval for the timer.
    @State private var activeAnimationInterval: TimeInterval = 0.5

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(currentDot == index ? 1.3 : 0.8)
                        .opacity(currentDot == index ? 1.0 : 0.5)
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
        .scaleEffect(isVisible ? 1.0 : 0.85)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            // Add entrance animation for typing indicator
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            // Set initial speed based on current emotions and start the timer
            updateActiveInterval(basedOn: self.latestEmotions)
            restartDotAnimationTimer()
        }
        .onChange(of: latestEmotions) { newEmotions in
            // Update speed and restart timer if emotions change
            updateActiveInterval(basedOn: newEmotions)
            restartDotAnimationTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = false
            }
        }
    }

    /// Calculates overall emotional intensity from bipolar emotion values
    private func calculateEmotionalIntensity(from emotions: [String: Int]?) -> Double {
        guard let emotions = emotions, !emotions.isEmpty else { return 0.0 }
        
        // Calculate average absolute intensity across all emotions
        let totalIntensity = emotions.values.reduce(0.0) { total, value in
            total + Double(abs(value)) / 100.0  // Normalize to 0-1 scale
        }
        
        return totalIntensity / Double(emotions.count)  // Average intensity
    }

    private func updateActiveInterval(basedOn emotions: [String: Int]?) {
        let intensity = calculateEmotionalIntensity(from: emotions)
        
        // Higher intensity = faster typing (lower interval)
        // Lower intensity = slower typing (higher interval)
        // Interpolate between minSpeed and maxSpeed based on intensity
        self.activeAnimationInterval = maxSpeed - (intensity * (maxSpeed - minSpeed))
        
        // Clamp to ensure we stay within bounds
        self.activeAnimationInterval = max(minSpeed, min(maxSpeed, self.activeAnimationInterval))
    }
    
    private func restartDotAnimationTimer() {
        timer?.invalidate() // Stop any existing timer
        timer = nil         // Ensure it's nilled out

        // Start a new timer with the (potentially updated) activeAnimationInterval
        timer = Timer.scheduledTimer(withTimeInterval: self.activeAnimationInterval, repeats: true) { _ in
            // Make the dot's own visual animation duration proportional to the timer interval
            // Use max to ensure a minimum animation duration, e.g., 0.1s
            let dotVisualAnimationDuration = max(0.1, self.activeAnimationInterval * 0.8)
            withAnimation(.easeInOut(duration: dotVisualAnimationDuration)) { // Smooth transition for dot scaling/opacity
                currentDot = (currentDot + 1) % 3
            }
        }
    }
}

#Preview {
    VStack {
        MessageBubble(message: Message(content: "Hello, how can I help you today?", isFromUser: false))
        MessageBubble(message: Message(content: "I need help with SwiftUI", isFromUser: true))
        TypingIndicator(latestEmotions: ["Sadness_Joy": 70, "Disgust_Trust": -30]) // High joy, some disgust
        TypingIndicator(latestEmotions: ["Fear_Anger": 80, "Anticipation_Surprise": 0]) // High anger, neutral surprise
        TypingIndicator(latestEmotions: ["Sadness_Joy": -50, "Fear_Anger": -80]) // Sadness and fear
        TypingIndicator(latestEmotions: ["Anticipation_Surprise": 90]) // High surprise
        TypingIndicator(latestEmotions: nil) // No emotions (should use base speed)
    }
}
