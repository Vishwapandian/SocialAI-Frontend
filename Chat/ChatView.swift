import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isInputFocused = false
    @State private var showingResetConfirmation = false
    @State private var showingSheet = false
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    // State variables for the gradient
    @State private var gradientStops: [Gradient.Stop] = [
        Gradient.Stop(color: Self.defaultAuraColor, location: 0),
        Gradient.Stop(color: Self.defaultAuraColor, location: 1)
    ]
    @State private var animateGradient = false

    // New: Emotion to Color Mapping and default color
    static let emotionColorMapping: [String: Color] = [
        "Yellow": .yellow,
        "Blue": .blue,
        "Red": .red,
        "Purple": .purple,
        "Green": .green
    ]
    static let defaultAuraColor: Color = Color.gray.opacity(0.3)

    var body: some View {
        ZStack {
            auraBackground
            chatList
            VStack {
                HStack {
                    Button {
                        showingSheet = true
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
        .sheet(isPresented: $showingSheet) {
            SheetView(viewModel: viewModel)
                .environmentObject(auth)
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
        .blur(radius: 60)
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

// Updated private function to update gradient stops based on emotion magnitudes
extension ChatView {
    private func updateGradientStops(from emotions: [String: Int]?) {
        guard let emotions = emotions, !emotions.isEmpty else {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        let activeSortedEmotions = emotions
            //.filter { $0.value >= 15 }
            .sorted { $0.value > $1.value }

        if activeSortedEmotions.isEmpty {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        if activeSortedEmotions.count == 1 {
            let emotion = activeSortedEmotions[0]
            let color = Self.emotionColorMapping[emotion.key] ?? Self.defaultAuraColor
            self.gradientStops = [
                Gradient.Stop(color: color, location: 0),
                Gradient.Stop(color: color, location: 1)
            ]
            return
        }

        let totalIntensity = CGFloat(activeSortedEmotions.reduce(0) { $0 + $1.value })
        guard totalIntensity > 0 else {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        var newStops: [Gradient.Stop] = []
        var cumulativeProportion: CGFloat = 0.0

        for i in 0..<activeSortedEmotions.count {
            let emotionEntry = activeSortedEmotions[i]
            let color = Self.emotionColorMapping[emotionEntry.key] ?? Self.defaultAuraColor
            
            if i == 0 {
                // First emotion's color starts at location 0.0
                newStops.append(Gradient.Stop(color: color, location: 0.0))
            }
            
            let intensity = CGFloat(emotionEntry.value)
            cumulativeProportion += intensity / totalIntensity
            let locationForThisColorSegmentEnd = min(cumulativeProportion, 1.0) // Cap at 1.0
            
            // Add a stop for the current emotion's color at the end of its proportional segment.
            // This structure [Stop(C1,0), Stop(C1,L1), Stop(C2,L2), Stop(C3,L3=1)] creates:
            // Solid C1 from 0-L1, then gradient C1->C2 from L1-L2, then C2->C3 from L2-L3.
            newStops.append(Gradient.Stop(color: color, location: locationForThisColorSegmentEnd))
        }

        // Cleanup: Remove truly duplicate consecutive stops (same color and same location).
        // This can happen if an intensity is extremely small leading to no change in location after min().
        if newStops.count > 1 {
            var uniqueStops: [Gradient.Stop] = [newStops[0]]
            for j in 1..<newStops.count {
                let lastAddedStop = uniqueStops.last!
                let currentStopToConsider = newStops[j]
                if !(currentStopToConsider.color == lastAddedStop.color && currentStopToConsider.location == lastAddedStop.location) {
                    uniqueStops.append(currentStopToConsider)
                }
            }
            newStops = uniqueStops
        }
        
        // Ensure gradient is valid (at least two stops). This should be guaranteed by count == 1 case,
        // but as a safeguard if newStops somehow ends up with one.
        if newStops.count == 1, let firstStop = newStops.first {
             newStops.append(Gradient.Stop(color: firstStop.color, location: 1.0))
        }


        self.gradientStops = newStops.isEmpty ? [ // Final safeguard
            Gradient.Stop(color: Self.defaultAuraColor, location: 0),
            Gradient.Stop(color: Self.defaultAuraColor, location: 1)
        ] : newStops
    }
}
