import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: ChatViewModel
    @State private var isInputFocused = false
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    // State variables for the gradient
    @State private var gradientColors: [Color] = ChatView.generateRandomColors()
    @State private var animateGradient = false

    // The main colors for the aura
    static let auraColors: [Color] = [.yellow, .blue, .purple, .green, .red]

    // Timer to change the colors periodically
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // The fluctuating aura background
            RadialGradient(
                gradient: Gradient(colors: gradientColors),
                center: .center,
                startRadius: 50,
                endRadius: 500 // Adjust for desired spread
            )
            .blur(radius: 60) // Soften the edges for an aura effect
            .animation(.easeInOut(duration: 5), value: animateGradient) // Animate color changes
            .ignoresSafeArea() // Make the background fill the entire screen

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.currentConversation.messages.isEmpty {
                            welcomeView
                                .id("welcomeView")
                        }
                        ForEach(viewModel.currentConversation.messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                            MessageBubble(message: message)
                        }
                        Spacer()
                            .frame(height: 1)
                            .id("bottomSpacer")
                    }
                    .padding(.vertical)
                }
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.05)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .onChange(of: viewModel.currentConversation.messages) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        if viewModel.currentConversation.messages.isEmpty {
                            proxy.scrollTo("welcomeView", anchor: .bottom)
                        } else {
                            proxy.scrollTo("bottomSpacer", anchor: .bottom)
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
                    isFocused: $isInputFocused
                )
                .padding(.horizontal)
                .background(
                    ZStack {
                        Color.clear
                        RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                            .fill(Color("birdieSecondary").opacity(0.5))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.requestEmotionDisplay()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("birdieSecondary"))
                        .fontWeight(.bold)
                }
            }
            
            /*
            if !viewModel.currentConversation.messages.isEmpty {
                ToolbarItem(placement: .principal) {
                    Image("birdie")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }
            */
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Sign out", role: .destructive) { auth.signOut() }
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(Color("birdieSecondary"))
                        .fontWeight(.bold)
                }
            }
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
            setupNavigationBarAppearance()
            self.animateGradient.toggle()
        }
        .onReceive(timer) { _ in
            self.gradientColors = Self.generateRandomColors()
            self.animateGradient.toggle()
        }
    }

    private func setupNavigationBarAppearance() {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController?.findNavigationController() {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.shadowColor = .clear
                appearance.backgroundColor = .clear
                
                navigationController.navigationBar.standardAppearance = appearance
                navigationController.navigationBar.compactAppearance = appearance
                navigationController.navigationBar.scrollEdgeAppearance = appearance
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            /*
            Spacer()
            Image("birdie")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            Text("Tell a little Birdie!")
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
            Spacer()
             */
        }
        .padding()
    }
}

extension UIViewController {
    func findNavigationController() -> UINavigationController? {
        if let nav = self as? UINavigationController {
            return nav
        }
        for child in children {
            if let nav = child.findNavigationController() {
                return nav
            }
        }
        return nil
    }
}

extension ChatView {
    static func generateRandomColors() -> [Color] {
        var shuffledColors = auraColors.shuffled()
        let numberOfColors = Int.random(in: 2...shuffledColors.count)
        var colorsToShow = Array(shuffledColors.prefix(numberOfColors))
        if colorsToShow.count < 2 {
            colorsToShow.append(auraColors.randomElement() ?? .clear)
            if colorsToShow.count < 2 {
                colorsToShow.append(auraColors.randomElement() ?? .black)
            }
        }
        return colorsToShow
    }
}
