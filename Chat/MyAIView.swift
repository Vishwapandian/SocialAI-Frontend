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
    
    // State variables for the aura preview
    @State private var animateGradient = false
    
    var body: some View {
        ScrollView {
            HStack {
                // Create new persona
                Button {
                    viewModel.createPersona { persona in
                        self.personaToEdit = persona
                        self.showingEditView = true
                    }
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
                // Personas list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personas")
                        .font(.headline)
                    // Display personas as aura previews in a responsive grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 24)], spacing: 24) {
                        ForEach(viewModel.personas, id: \.self) { persona in
                            Button {
                                self.personaToEdit = persona
                                self.showingEditView = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    AuraPreviewView(emotions: persona.baseEmotions)
                                        .animation(.easeInOut(duration: 3), value: animateGradient)
                                        .frame(width: 120, height: 120)

                                    if viewModel.selectedPersonaId == persona.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .padding(6)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            // Name label below the aura preview for clarity
                            .overlay(alignment: .bottom) {
                                Text(persona.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
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
        .onAppear {
            viewModel.loadPersonas()
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
        
        // Add mock personas for preview
        mockViewModel.personas = [
            SocialAIService.Persona(
                id: "1",
                name: "Calm",
                baseEmotions: ["Red": 5, "Yellow": 10, "Green": 60, "Blue": 20, "Purple": 5],
                sensitivity: 30,
                customInstructions: "Be calm and peaceful"
            ),
            SocialAIService.Persona(
                id: "2", 
                name: "Energetic",
                baseEmotions: ["Red": 25, "Yellow": 50, "Green": 10, "Blue": 10, "Purple": 5],
                sensitivity: 80,
                customInstructions: "Be energetic and enthusiastic"
            ),
            SocialAIService.Persona(
                id: "3",
                name: "Thoughtful", 
                baseEmotions: ["Red": 5, "Yellow": 15, "Green": 25, "Blue": 45, "Purple": 10],
                sensitivity: 45,
                customInstructions: "Be thoughtful and analytical"
            ),
            SocialAIService.Persona(
                id: "4",
                name: "Creative",
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
