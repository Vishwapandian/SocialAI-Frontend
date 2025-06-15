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
        ZStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(viewModel.personas, id: \.id) { persona in
                        Button {
                            personaToEdit = persona
                            showingEditView = true
                        } label: {
                            VStack(spacing: 12) {
                                Spacer()
                                AuraPreviewView(
                                    emotions: persona.baseEmotions,
                                    size: 150
                                )
                                
                                Text(persona.name)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .opacity(0.7)
                                
                                HStack {
                                    Spacer()
                                }
                                
                                Spacer()
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(outermostAuraColor(for: persona.baseEmotions).opacity(0.05))
                            )
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
            
            VStack {
                HStack {
                    // Create new persona
                    Button {
                        viewModel.createPersona { persona in
                            self.personaToEdit = persona
                            self.showingEditView = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                    }
                    
                    Spacer()
                    
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
                }
                .padding()
                Spacer()
            }
        }
        .background(
            colorScheme == .light
                ? Color(red: 240/255, green: 240/255, blue: 240/255)
                : Color.clear
        )
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
                dismiss()
            }
        } message: {
            Text("This will permanently delete all of Auri's memories and reset emotions to default values. This action cannot be undone.")
        }
    }
    
    private func outermostAuraColor(for emotions: [String: Int]) -> Color {
        // Filter out emotions with zero intensity
        let active = emotions.filter { $0.value > 0 }

        // If there are no active emotions fall back to the default aura color
        guard !active.isEmpty else { return EditView.defaultAuraColor }

        // Emotions are sorted descending in `AuraPreviewView` – the last one is the least intense
        let leastIntenseEmotion = active.sorted { $0.value > $1.value }.last!

        // Map the emotion name to its display color
        return EditView.emotionColorMapping[leastIntenseEmotion.key] ?? EditView.defaultAuraColor
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
        
        // Add mock personas for preview
        mockViewModel.personas = [
            SocialAIService.Persona(
                id: "1",
                name: "Gemini",
                baseEmotions: ["Red": 5, "Yellow": 10, "Green": 60, "Blue": 20, "Purple": 5],
                sensitivity: 30,
                customInstructions: "Be calm and peaceful"
            ),
            SocialAIService.Persona(
                id: "2", 
                name: "Taurus",
                baseEmotions: ["Red": 25, "Yellow": 50, "Green": 10, "Blue": 10, "Purple": 5],
                sensitivity: 80,
                customInstructions: "Be energetic and enthusiastic"
            ),
            SocialAIService.Persona(
                id: "3",
                name: "Cancer",
                baseEmotions: ["Red": 5, "Yellow": 15, "Green": 25, "Blue": 45, "Purple": 10],
                sensitivity: 45,
                customInstructions: "Be thoughtful and analytical"
            ),
            SocialAIService.Persona(
                id: "4",
                name: "Virgo",
                baseEmotions: ["Red": 10, "Yellow": 20, "Green": 20, "Blue": 20, "Purple": 30],
                sensitivity: 60,
                customInstructions: "Be creative and imaginative"
            )
        ]
        
        return mockViewModel
    }())
    .environmentObject({
        let mockAuth = AuthViewModel()
        return mockAuth
    }())
}
