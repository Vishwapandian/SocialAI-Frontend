import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isInputFocused = false
    @State private var showingResetConfirmation = false
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    // Callback that lets a parent view control the presentation of `MyAIView`.
    var openMyAI: () -> Void = {}

    var body: some View {
        ZStack {
            // Simple background that adapts to light/dark mode
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            chatList
            VStack {
                HStack {
                    Button {
                        // Delegate the action to the parent container.
                        openMyAI()
                    } label: {
                        Image(systemName: "microbe.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
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
        .onAppear {
            // Resume emotion polling when view appears
            viewModel.resumeEmotionPolling()
        }
        .onDisappear {
            // Pause emotion polling when view disappears
            viewModel.pauseEmotionPolling()
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
