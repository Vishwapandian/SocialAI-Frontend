import SwiftUI

struct ContentView: View {
    var body: some View {
        let viewModel = ChatViewModel()
        //NavigationView {
            ChatView(viewModel: viewModel)
        //}
    }
}

#Preview {
    ContentView()
}
