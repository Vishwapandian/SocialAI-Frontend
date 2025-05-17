import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: ChatViewModel
    @State private var isInputFocused = false
    @State private var knowledgeContent = ""
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    // State variables for the gradient
    @State private var gradientColors: [Color] = ChatView.generateRandomColors()
    @State private var animateGradient = false

    // The main colors for the aura
    static let auraColors: [Color] = [.yellow, .blue, .purple, .green, .red]

    // Timer to change the colors periodically
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

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
            .animation(.easeInOut(duration: 2), value: animateGradient) // Animate color changes
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
                // Let SwiftUI handle moving content above the keyboard
                .ignoresSafeArea(.keyboard, edges: .bottom)
                // Whenever new message arrives, scroll to bottom (with a tiny delay)
                .onChange(of: viewModel.currentConversation.messages) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
                    }
                }
                // Scroll when keyboard shows
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
                    }
                }
                // Scroll when keyboard hides
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
                    }
                }
                // Initial scroll on appear
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
                        //Color("birdieBackground") // Old background
                        // Make input background transparent to show gradient
                        Color.clear 
                        RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                            .fill(Color("birdieSecondary").opacity(0.5))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        //.navigationTitle("Birdie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // Left toolbar placeholder
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.primary)
                }
            }
            
            if !viewModel.currentConversation.messages.isEmpty {
                ToolbarItem(placement: .principal) {
                    Image("birdie")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Sign out", role: .destructive) { auth.signOut() }
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.primary)
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
        .onAppear {
            setupNavigationBarAppearance()
            // Initial animation trigger
            self.animateGradient.toggle()
        }
        .onChange(of: colorScheme) { _ in
            setupNavigationBarAppearance()
        }
        .onReceive(timer) { _ in
            // Trigger a new set of random colors and the animation
            self.gradientColors = Self.generateRandomColors()
            self.animateGradient.toggle()
        }
    }

    private func setupNavigationBarAppearance() {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController?.findNavigationController() {
                // Configure navigation bar appearance
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.shadowColor = .clear
                appearance.backgroundColor = .clear
                
                navigationController.navigationBar.standardAppearance = appearance
                navigationController.navigationBar.compactAppearance = appearance
                navigationController.navigationBar.scrollEdgeAppearance = appearance
                
                // Update shadow color dynamically
                navigationController.navigationBar.layer.shadowColor = UIColor.clear.cgColor
                navigationController.navigationBar.layer.shadowOffset = CGSize(width: 0, height: 20)
                navigationController.navigationBar.layer.shadowRadius = 8
                navigationController.navigationBar.layer.shadowOpacity = 1
                navigationController.navigationBar.layer.masksToBounds = false
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
                //.foregroundColor(Color(red: 61/255, green: 107/255, blue: 171/255)) // Keep or make adaptable
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7)) // Adapting to gradient
            Text("Tell a little Birdie!")
                .font(.subheadline)
                //.foregroundColor(.secondary) // Keep or make adaptable
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)) // Adapting to gradient
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

// Add the color generation function
extension ChatView {
    static func generateRandomColors() -> [Color] {
        // Shuffle the main aura colors
        var shuffledColors = auraColors.shuffled()
        // Take a random number of colors (at least 2 for a gradient)
        let numberOfColors = Int.random(in: 2...shuffledColors.count)
        // Ensure we have distinct colors for the start and end of the base gradient
        // and add more random colors in between if needed.
        var colorsToShow = Array(shuffledColors.prefix(numberOfColors))

        // To make the gradient more dynamic, sometimes we might want to repeat colors
        // or ensure the start and end points are different.
        // For simplicity, we're just taking a random slice.
        // You can add more sophisticated logic here for color combinations.

        // Ensure there are at least two colors for a gradient
        if colorsToShow.count < 2 {
            colorsToShow.append(auraColors.randomElement() ?? .clear) // Fallback color
            if colorsToShow.count < 2 { // If still less than 2 (e.g. auraColors was empty or had 1 element)
                 colorsToShow.append(auraColors.randomElement() ?? .black) // Another fallback
            }
        }
        return colorsToShow
    }
}
