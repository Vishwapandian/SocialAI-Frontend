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
            Color(UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor.black
                    : UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
            })
            .ignoresSafeArea()

            ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if viewModel.currentConversation.messages.isEmpty {
                                welcomeView
                                    .id("welcomeView")
                            } else {
                                ForEach(viewModel.currentConversation.messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                Spacer()
                                    .frame(height: 1)
                                    .id("bottomSpacer")
                            }
                        }
                        .padding(.vertical)
                    }
                    .background(Color(UIColor { traitCollection in
                        return traitCollection.userInterfaceStyle == .dark ?
                            UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0) :
                            UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
                    }))
                    /*
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(UIColor { traitCollection in
                                return traitCollection.userInterfaceStyle == .dark ?
                                    UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0) :
                                    UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
                            }),
                            Color(UIColor { traitCollection in
                                return traitCollection.userInterfaceStyle == .dark ?
                                    UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 0.0) :
                                    UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 0.0)
                            })
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 15)
                    */
                }
                .onChange(of: viewModel.currentConversation.messages) { _, newMessages in
                    if let lastMessage = newMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isInputFocused) { _, newValue in
                    if newValue {
                        if viewModel.currentConversation.messages.isEmpty {
                            proxy.scrollTo("welcomeView", anchor: .bottom)
                        } else {
                            withAnimation {
                                proxy.scrollTo("bottomSpacer", anchor: .bottom)
                            }
                        }
                    }
                }
                .onAppear {
                    if viewModel.currentConversation.messages.isEmpty {
                        proxy.scrollTo("welcomeView", anchor: .bottom)
                    } else if let lastMessage = viewModel.currentConversation.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
                        Color(UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark
                                ? UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0)
                                : UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
                        })
                        RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                            .fill(Color(UIColor { traitCollection in
                                traitCollection.userInterfaceStyle == .dark
                                    ? UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1.0)
                                    : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
                            }))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        //.navigationTitle(viewModel.currentConversation.title)
        .navigationTitle("Birdie")
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

                    appearance.backgroundColor = UIColor { traitCollection in
                        return traitCollection.userInterfaceStyle == .dark ?
                            UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1.0) :
                            UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
                    }

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

            NotificationCenter.default.removeObserver(self)
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

            //Text("Journly")
            //    .font(.largeTitle)
            //    .fontWeight(.bold)

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
