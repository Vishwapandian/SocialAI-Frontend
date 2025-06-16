import SwiftUI

struct ContentView: View {
    // Shared view-model for both chat and persona editor.
    @StateObject private var viewModel = ChatViewModel()
    // Tracks whether the side view is fully revealed.
    @State private var isMyAIVisible = false
    // Temporary horizontal drag offset during an in-progress gesture.
    @State private var dragOffset: CGFloat = 0
    // How far the chat should slide to reveal the underlying view (as a fraction of the screen).
    private let revealRatio: CGFloat = 1

    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        GeometryReader { geo in
            let revealDistance = geo.size.width * revealRatio

            ZStack(alignment: .leading) {
                // Underlying editable persona view.
                MyAIView(viewModel: viewModel)
                    .frame(width: geo.size.width)
                    // Keep entirely off-screen when closed, apply a subtle parallax while swiping.
                    .offset(x: (isMyAIVisible ? 0 : -geo.size.width) + dragOffset * 0.3)
                    .environmentObject(auth)

                // Foreground chat view.
                ChatView(viewModel: viewModel, openMyAI: {
                    withAnimation(.easeInOut) {
                        isMyAIVisible = true
                    }
                })
                .frame(width: geo.size.width)
                .offset(x: (isMyAIVisible ? revealDistance : 0) + dragOffset)
                .disabled(isMyAIVisible) // Optional: prevent interactions when fully open.
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            // Opening gesture (swiping right) allowed only when closed.
                            // Closing gesture (swiping left) allowed only when open.
                            if (!isMyAIVisible && translation > 0) {
                                dragOffset = min(translation, revealDistance)
                            } else if (isMyAIVisible && translation < 0) {
                                dragOffset = max(translation, -revealDistance)
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            let threshold = geo.size.width * 0.25

                            withAnimation(.easeInOut) {
                                if !isMyAIVisible {
                                    // Decide to open.
                                    if translation > threshold {
                                        isMyAIVisible = true
                                    }
                                } else {
                                    // Decide to close.
                                    if translation < -threshold {
                                        isMyAIVisible = false
                                    }
                                }
                                dragOffset = 0
                            }
                        }
                )
                .environmentObject(auth)
            }
            // Animate state changes.
            .animation(.easeInOut, value: isMyAIVisible)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
