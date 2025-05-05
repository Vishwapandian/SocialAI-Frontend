import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: ChatViewModel
    @State private var isInputFocused = false
    @State private var knowledgeContent = ""
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        ZStack {
            Color("birdieBackground")
            .ignoresSafeArea()

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
                        Color("birdieBackground")
                        RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                            .fill(Color("birdieSecondary"))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
            .overlay(
                LinearGradient(
                    colors: [
                        Color("birdieBackground"),
                        Color("birdieBackground").opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 25)
                .allowsHitTesting(false),
                alignment: .top
            )
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
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let navigationController = window.rootViewController?.findNavigationController() {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithDefaultBackground()
                    appearance.shadowColor = .clear

                    appearance.backgroundColor = UIColor(named: "birdieBackground")

                    navigationController.navigationBar.standardAppearance = appearance
                    navigationController.navigationBar.compactAppearance = appearance
                    navigationController.navigationBar.scrollEdgeAppearance = appearance
                }
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let navigationController = window.rootViewController?.findNavigationController() {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithDefaultBackground()

                    navigationController.navigationBar.standardAppearance = appearance
                    navigationController.navigationBar.compactAppearance = appearance
                    navigationController.navigationBar.scrollEdgeAppearance = appearance
                }
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("birdie")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(Color(red: 61/255, green: 107/255, blue: 171/255))
            Text("Tell a little Birdie!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
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
