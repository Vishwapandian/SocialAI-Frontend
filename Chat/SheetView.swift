import SwiftUI

struct SheetView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        NavigationView {
            Text("This is a placeholder sheet view.")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewModel.requestEmotionDisplay()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Sign out", role: .destructive) { auth.signOut() }
                        } label: {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                        }
                    }
                }
        }
    }
}

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        SheetView(viewModel: ChatViewModel())
            .environmentObject(AuthViewModel())
    }
} 
