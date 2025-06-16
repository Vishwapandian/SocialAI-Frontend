import SwiftUI

struct MyAIView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChatViewModel
    @State private var showingSignOutConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var showingEditView = false
    @State private var personaToEdit: SocialAIService.Persona? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Background Gradient
                
                /*
                RadialGradient(
                            // 1. Define the colors for the gradient
                    gradient: Gradient(colors: [Color.gray.opacity(0.25), .clear]),
                    center: .trailing,
                    startRadius: 50,
                    endRadius: 500
                        )
                .ignoresSafeArea()
                */

                HStack(spacing: 0) {
                    // MARK: - Main Content (80% width)
                    ZStack {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                Button {
                                    viewModel.createPersona { persona in
                                        self.personaToEdit = persona
                                        self.showingEditView = true
                                    }
                                } label: {
                                    HStack {
                                        GrayAuraView(size: 80)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Create New")
                                                .font(.headline)
                                                .multilineTextAlignment(.leading)
                                                .opacity(0.75)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    /*
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                                    */
                                }
                                .buttonStyle(PlainButtonStyle())
                                ForEach(viewModel.personas, id: \.id) { persona in
                                    Button {
                                        personaToEdit = persona
                                        showingEditView = true
                                    } label: {
                                        HStack {
                                            AuraPreviewView(
                                                emotions: persona.baseEmotions,
                                                size: 80
                                            )
                                            .padding(.trailing, 8)
                                            
                                            VStack(alignment: .leading) {
                                                Text(persona.name)
                                                    .font(.headline)
                                                    .multilineTextAlignment(.leading)
                                                    .opacity(0.75)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding()
                                        .if(viewModel.selectedPersonaId == persona.id) { view in
                                            view
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(.ultraThinMaterial)
                                                )
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(outermostAuraColor(for: persona.baseEmotions).opacity(0.05))
                                                )
                                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                                        }
                                        .if(viewModel.selectedPersonaId != persona.id) { view in
                                            view
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .foregroundColor(.clear)
                                                )
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 64)
                            .padding(.bottom, 16)
                            .animation(.easeInOut, value: viewModel.personas)
                        }
                        .scrollIndicators(.hidden)
                        
                        // MARK: - Overlay Buttons
                        VStack {
                            HStack {
                                
                                Menu {
                                    Button(role: .destructive) {
                                        showingResetConfirmation = true
                                    } label: {
                                        Text("Reset Auri")
                                    }
                                    
                                    Button {
                                        showingSignOutConfirmation = true
                                    } label: {
                                        Text("Sign Out")
                                    }
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(width: 30, height: 30)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            Spacer()
                        }
                    }
                    .frame(width: geometry.size.width * 0.8)

                    // MARK: - Empty Space (20% width)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            if let persona = personaToEdit {
                EditView(viewModel: viewModel, persona: persona)
                    .environmentObject(auth)
            } else {
                EditView(viewModel: viewModel)
                    .environmentObject(auth)
            }
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
            }
        } message: {
            Text("This will permanently delete all of Auri's memories and reset emotions to default values. This action cannot be undone.")
        }
    }
    
    private func outermostAuraColor(for emotions: [String: Int]) -> Color {
        let active = emotions.filter { $0.value > 0 }
        guard !active.isEmpty else { return EditView.defaultAuraColor }
        let leastIntenseEmotion = active.sorted { $0.value > $1.value }.last!
        return EditView.emotionColorMapping[leastIntenseEmotion.key] ?? EditView.defaultAuraColor
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// The Preview code remains the same
#Preview {
    MyAIView(viewModel: {
        let mockViewModel = ChatViewModel()
        mockViewModel.baseEmotions = [
            "Red": 5, "Yellow": 20, "Green": 30, "Blue": 40, "Purple": 5
        ]
        mockViewModel.sensitivity = 65
        mockViewModel.personas = [
            SocialAIService.Persona(id: "1", name: "Gemini", baseEmotions: ["Red": 5, "Yellow": 10, "Green": 60, "Blue": 20, "Purple": 5], sensitivity: 30, customInstructions: "Be calm and peaceful"),
            SocialAIService.Persona(id: "2", name: "Taurus", baseEmotions: ["Red": 25, "Yellow": 50, "Green": 10, "Blue": 10, "Purple": 5], sensitivity: 80, customInstructions: "Be energetic and enthusiastic"),
            SocialAIService.Persona(id: "3", name: "Cancer", baseEmotions: ["Red": 5, "Yellow": 15, "Green": 25, "Blue": 45, "Purple": 10], sensitivity: 45, customInstructions: "Be thoughtful and analytical"),
            SocialAIService.Persona(id: "4", name: "Virgo", baseEmotions: ["Red": 10, "Yellow": 20, "Green": 20, "Blue": 20, "Purple": 30], sensitivity: 60, customInstructions: "Be creative and imaginative")
        ]
        return mockViewModel
    }())
    .environmentObject({
        let mockAuth = AuthViewModel()
        return mockAuth
    }())
}

