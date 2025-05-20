import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: ChatViewModel
    @State private var isInputFocused = false
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
        "Joy": .yellow,
        "Sadness": .blue,
        "Anger": .red,
        "Fear": .purple,
        "Disgust": .green
    ]
    static let defaultAuraColor: Color = Color.gray.opacity(0.3)

    var body: some View {
        ZStack {
            // The fluctuating aura background
            RadialGradient(
                gradient: Gradient(stops: gradientStops),
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
            // Set initial colors based on current emotions
            updateGradientStops(from: viewModel.latestEmotions)
            self.animateGradient.toggle() // Initial animation
        }
        .onChange(of: viewModel.latestEmotions) { newEmotions in
            updateGradientStops(from: newEmotions)
            self.animateGradient.toggle() // Trigger animation on emotion change
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
            .filter { $0.value >= 15 }
            .sorted { $0.value < $1.value }

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
