import SwiftUI

struct MyAIView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChatViewModel
    @State private var showingSignOutConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var showingEditView = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // State variables for the aura preview
    @State private var animateGradient = false
    
    var body: some View {
        ScrollView {
            HStack {
                Button {
                    //
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.primary)
                        //.foregroundStyle(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                        //.padding()
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Auri")
                        }
                    }
                    
                    Button {
                        showingSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "person.fill.xmark")
                            Text("Sign Out")
                        }
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.primary)
                        //.foregroundStyle(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                        //.padding()
                }
                
                
            }
            .padding()
            VStack(spacing: 32) {
                // Aura Preview Button
                VStack(spacing: 16) {
                    
                    Button {
                        showingEditView = true
                    } label: {
                        AuraPreviewView(emotions: viewModel.latestEmotions ?? viewModel.baseEmotions)
                            .animation(.easeInOut(duration: 3), value: animateGradient)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Tap to customize")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                

                
                Spacer()
            }
            .padding()
        }
        .background(
            colorScheme == .light
                ? Color(red: 240/255, green: 240/255, blue: 240/255)
                : Color.clear
        )
        .sheet(isPresented: $showingEditView) {
            EditView(viewModel: viewModel)
                .environmentObject(auth)
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                auth.signOut()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Reset Auri", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetMemoryAndChat()
                dismiss()
            }
        } message: {
            Text("This will permanently delete all of Auri's memories and reset emotions to default values. This action cannot be undone.")
        }
        .onAppear {
            animateGradient.toggle()
        }
        .onChange(of: viewModel.latestEmotions) { _ in
            animateGradient.toggle()
        }
    }
}

#Preview {
    MyAIView(viewModel: {
        let mockViewModel = ChatViewModel()
        mockViewModel.baseEmotions = [
            "Red": 5,
            "Yellow": 20,
            "Green": 30,
            "Blue": 40,
            "Purple": 5
        ]
        mockViewModel.sensitivity = 65
        return mockViewModel
    }())
    .environmentObject({
        let mockAuth = AuthViewModel()
        return mockAuth
    }())
} 
