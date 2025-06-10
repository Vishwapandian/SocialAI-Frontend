import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isInputFocused = false
    @State private var showingResetConfirmation = false
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    // State variables for the gradient
    @State private var gradientStops: [Gradient.Stop] = [
        Gradient.Stop(color: Self.defaultAuraColor, location: 0),
        Gradient.Stop(color: Self.defaultAuraColor, location: 1)
    ]
    @State private var animateGradient = false

    // Updated: Bipolar Emotion to Color Mapping
    static let bipolarEmotionMapping: [String: (negativeColor: Color, positiveColor: Color)] = [
        "Sadness_Joy": (negativeColor: .blue, positiveColor: .yellow),        // Sadness (-100) -> Joy (+100)
        "Disgust_Trust": (negativeColor: .green, positiveColor: .blue),       // Disgust (-100) -> Trust (+100)
        "Fear_Anger": (negativeColor: .purple, positiveColor: .red),          // Fear (-100) -> Anger (+100)
        "Anticipation_Surprise": (negativeColor: .purple, positiveColor: .yellow) // Anticipation (-100) -> Surprise (+100)
    ]
    static let defaultAuraColor: Color = Color.gray.opacity(0.6)

    var body: some View {
        ZStack {
            auraBackground
            chatList
            VStack {
                HStack {
                    Menu {
                        ///*
                        Button("Get Emotional State") {
                            viewModel.requestEmotionDisplay()
                        }
                        //*/
                        
                        Button("Reset Auri", role: .destructive) {
                            showingResetConfirmation = true
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            auth.signOut()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle.fill")
                            .resizable()
                            .symbolRenderingMode(.palette)
                            .frame(width: 30, height: 30)
                            .foregroundStyle(.white, .ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .onTapGesture {
            // Dismiss keyboard/input focus when tapping background
            isInputFocused = false
        }
        .alert(isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.error ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("AI Emotional State", isPresented: .init(
            get: { viewModel.emotionDisplayContent != nil },
            set: { if !$0 { viewModel.emotionDisplayContent = nil } }
        )) {
            Button("OK") {
                viewModel.emotionDisplayContent = nil
            }
        } message: {
            if let content = viewModel.emotionDisplayContent {
                Text(content)
            }
        }
        .alert("Reset Auri", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetMemoryAndChat()
            }
        } message: {
            Text("Are you sure you want to reset all data? This will restore the Auri's memory to factory settings and cannot be undone.")
        }
        .onAppear {
            updateGradientStops(from: viewModel.latestEmotions)
            animateGradient.toggle()
            // Resume emotion polling when view appears
            viewModel.resumeEmotionPolling()
        }
        .onDisappear {
            // Pause emotion polling when view disappears
            viewModel.pauseEmotionPolling()
        }
        .onChange(of: viewModel.latestEmotions) { newEmotions in
            updateGradientStops(from: newEmotions)
            animateGradient.toggle()
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            /*
            Spacer()
            Image("birdie")
                .resizable()
                .scaledToFit()
                .frame(width: 500, height: 500)
            Text("Tell a little Birdie!")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
            Spacer()
            */
        }
        .padding()
    }

    // Extracted aura background view
    private var auraBackground: some View {
        RadialGradient(
            gradient: Gradient(stops: gradientStops),
            center: .center,
            startRadius: 50,
            endRadius: 500
        )
        .blur(radius: 50)
        .animation(.easeInOut(duration: 5), value: animateGradient)
        .ignoresSafeArea()
    }

    // Extracted chat list view
    private var chatList: some View {
        // Compute sorted messages for consistent ordering and spacing logic
        let sortedMessages = viewModel.messages.sorted(by: { $0.timestamp < $1.timestamp })
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        welcomeView
                            .id("welcomeView")
                    }
                    ForEach(Array(sortedMessages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(message: message)
                            // Closer spacing for consecutive messages from the same user
                            .padding(.top, (index > 0 && sortedMessages[index - 1].isFromUser == message.isFromUser) ? 4 : 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                removal: .opacity.combined(with: .scale(scale: 0.8))
                            ))
                    }
                    
                    // Add typing indicator when AI is typing
                    if viewModel.isAITyping {
                        TypingIndicator(latestEmotions: viewModel.latestEmotions)
                            // Closer spacing after AI message, normal spacing if no messages or after user message
                            .padding(.top, (!sortedMessages.isEmpty && !sortedMessages.last!.isFromUser) ? 4 : 20)
                            .id("typingIndicator")
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                removal: .opacity.combined(with: .scale(scale: 0.8))
                            ))
                    }
                    
                    Spacer()
                        .frame(height: 1)
                        .id("bottomSpacer")
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.messages.count)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.isAITyping)
                .padding(.top, 60)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: viewModel.messages) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { 
                        proxy.scrollTo("bottomSpacer", anchor: .bottom) 
                    }
                }
            }
            .onChange(of: viewModel.isAITyping) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { 
                        proxy.scrollTo("bottomSpacer", anchor: .bottom) 
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                        proxy.scrollTo("bottomSpacer", anchor: .bottom) 
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                        proxy.scrollTo("bottomSpacer", anchor: .bottom) 
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    if viewModel.messages.isEmpty {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("welcomeView", anchor: .bottom)
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("bottomSpacer", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            MessageInputView(
                message: $viewModel.currentMessage,
                onSend: {
                    viewModel.sendMessage()
                },
                onMessageChanged: {
                    viewModel.onMessageInputChanged()
                },
                isFocused: $isInputFocused
            )
            .padding(.horizontal)
            .background(
                ZStack {
                    RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                        .foregroundStyle(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)

                }
                .ignoresSafeArea(edges: .bottom)
            )
        }
         .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
    }
}

// Updated extension to handle bipolar emotion scales
extension ChatView {
    /// Maps a bipolar emotion value (-100 to +100) to a color between the negative and positive endpoints
    private func colorForBipolarEmotion(key: String, value: Int) -> Color {
        guard let mapping = Self.bipolarEmotionMapping[key] else {
            return Self.defaultAuraColor
        }
        
        // Clamp value to [-100, 100] range
        let clampedValue = max(-100, min(100, value))
        
        // Convert to 0-1 range where 0 = negative extreme, 0.5 = neutral, 1 = positive extreme
        let normalizedValue = Double(clampedValue + 100) / 200.0
        
        // Interpolate between negative and positive colors
        return interpolateColor(
            from: mapping.negativeColor,
            to: mapping.positiveColor,
            ratio: normalizedValue
        )
    }
    
    /// Interpolates between two colors based on a ratio (0.0 to 1.0) with enhanced saturation
    private func interpolateColor(from startColor: Color, to endColor: Color, ratio: Double) -> Color {
        let clampedRatio = max(0.0, min(1.0, ratio))
        
        // Convert SwiftUI Colors to UIColor to access RGB components
        let startUIColor = UIColor(startColor)
        let endUIColor = UIColor(endColor)
        
        var startRed: CGFloat = 0, startGreen: CGFloat = 0, startBlue: CGFloat = 0, startAlpha: CGFloat = 0
        var endRed: CGFloat = 0, endGreen: CGFloat = 0, endBlue: CGFloat = 0, endAlpha: CGFloat = 0
        
        startUIColor.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha)
        endUIColor.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha)
        
        let interpolatedRed = startRed + (endRed - startRed) * clampedRatio
        let interpolatedGreen = startGreen + (endGreen - startGreen) * clampedRatio
        let interpolatedBlue = startBlue + (endBlue - startBlue) * clampedRatio
        let interpolatedAlpha = startAlpha + (endAlpha - startAlpha) * clampedRatio
        
        // Enhance saturation for better visibility
        let enhancedColor = Color(
            red: Double(interpolatedRed),
            green: Double(interpolatedGreen),
            blue: Double(interpolatedBlue),
            opacity: Double(interpolatedAlpha)
        )
        
        // Increase saturation by converting to HSB and boosting saturation
        let uiColor = UIColor(enhancedColor)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost saturation for more vivid colors (especially important near neutral)
        let boostedSaturation = min(1.0, saturation * 1.4 + 0.2)
        let boostedBrightness = max(0.3, min(1.0, brightness * 1.1))
        
        return Color(
            hue: Double(hue),
            saturation: Double(boostedSaturation),
            brightness: Double(boostedBrightness),
            opacity: Double(alpha)
        )
    }
    
    /// Calculates the absolute intensity of an emotion (distance from neutral)
    private func emotionIntensity(value: Int) -> Double {
        return Double(abs(value)) / 100.0  // 0.0 to 1.0 scale
    }
    
    private func updateGradientStops(from emotions: [String: Int]?) {
        guard let emotions = emotions, !emotions.isEmpty else {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        // Convert emotions to colors and intensities, using a lower threshold for inclusion
        let emotionColorData: [(color: Color, intensity: Double)] = emotions.compactMap { (key, value) in
            let intensity = emotionIntensity(value: value)
            
            // Lower threshold - include even very small emotions for visibility
            guard intensity > 0.05 else { return nil }  // Reduced from 0.1 to 0.05
            
            let color = colorForBipolarEmotion(key: key, value: value)
            return (color: color, intensity: intensity)
        }
        
        // Sort by intensity (strongest emotions first)
        let sortedEmotions = emotionColorData.sorted { $0.intensity > $1.intensity }

        if sortedEmotions.isEmpty {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        if sortedEmotions.count == 1 {
            let emotion = sortedEmotions[0]
            // Increased base opacity and range for single emotion
            let colorWithIntensity = emotion.color.opacity(0.6 + emotion.intensity * 0.4)
            self.gradientStops = [
                Gradient.Stop(color: colorWithIntensity, location: 0),
                Gradient.Stop(color: colorWithIntensity, location: 1)
            ]
            return
        }

        // For multiple emotions, create gradient based on intensity weights
        let totalIntensity = sortedEmotions.reduce(0.0) { $0 + $1.intensity }
        guard totalIntensity > 0 else {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        var newStops: [Gradient.Stop] = []
        var cumulativeProportion: Double = 0.0

        for i in 0..<sortedEmotions.count {
            let emotion = sortedEmotions[i]
            // Increased base opacity and reduced intensity multiplier for more visible colors
            let colorWithIntensity = emotion.color.opacity(0.7 + emotion.intensity * 0.3)
            
            if i == 0 {
                // First emotion starts at location 0.0
                newStops.append(Gradient.Stop(color: colorWithIntensity, location: 0.0))
            }
            
            cumulativeProportion += emotion.intensity / totalIntensity
            let location = min(cumulativeProportion, 1.0)
            
            // Add stop for this emotion's segment end
            newStops.append(Gradient.Stop(color: colorWithIntensity, location: location))
        }

        // Remove duplicate consecutive stops
        if newStops.count > 1 {
            var uniqueStops: [Gradient.Stop] = [newStops[0]]
            for j in 1..<newStops.count {
                let lastStop = uniqueStops.last!
                let currentStop = newStops[j]
                if currentStop.location != lastStop.location {
                    uniqueStops.append(currentStop)
                }
            }
            newStops = uniqueStops
        }
        
        // Ensure we have at least two stops for a valid gradient
        if newStops.count == 1, let firstStop = newStops.first {
            newStops.append(Gradient.Stop(color: firstStop.color, location: 1.0))
        }

        self.gradientStops = newStops.isEmpty ? [
            Gradient.Stop(color: Self.defaultAuraColor, location: 0),
            Gradient.Stop(color: Self.defaultAuraColor, location: 1)
        ] : newStops
    }
}
