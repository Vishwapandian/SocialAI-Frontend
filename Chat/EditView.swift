import SwiftUI

struct EditView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChatViewModel
    var persona: SocialAIService.Persona? = nil // nil means editing user config
    var name: String = "Aura" // Default name for user config

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // NEW: Track if this persona was deleted during this editing session
    @State private var wasDeleted: Bool = false
    
    // State variables for editing (always in edit mode now)
    @State private var editedBaseEmotions: [String: Int] = [:]
    @State private var editedSensitivity: Double = 0
    @State private var editedCustomInstructions: String = "" // Editable field for future use
    @State private var editedName: String = "" // Editable name field
    
    // State used to drive the first-open "rubber-band" slider animation
    @State private var hasRunInitialSliderAnimation: Bool = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Name Configuration Section (only show for personas)
                    if persona != nil {
                        NameConfigSection(editedName: $editedName)
                    }
                    
                    Divider()
                    
                    EmotionsConfigSection(
                        viewModel: viewModel,
                        editedBaseEmotions: $editedBaseEmotions
                    )
                    
                    Divider()
                    
                    // Sensitivity Configuration Section
                    SensitivityConfigSection(viewModel: viewModel, editedSensitivity: $editedSensitivity)
                    
                    Divider()
                    
                    // Custom Instructions Configuration Section
                    CustomInstructionsConfigSection(viewModel: viewModel, editedCustomInstructions: $editedCustomInstructions)
                    
                    // Extra space for floating button
                    Spacer()
                        .frame(height: 40)
                }
                .padding()
            }
            .background(
                colorScheme == .light 
                    ? Color(red: 240/255, green: 240/255, blue: 240/255)
                    : Color.clear
            )
            
            // MARK: - Floating Buttons
            if let persona = persona {
                VStack {
                    // Delete button in top left (only show if not already selected)
                    if viewModel.selectedPersonaId != persona.id {
                        HStack {
                            Button(role: .destructive) {
                                // NEW: Mark this persona as deleted so we don't re-create it in onDisappear
                                wasDeleted = true
                                viewModel.deletePersona(personaId: persona.id ?? "") {
                                    dismiss()
                                }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                            }
                            .padding()
                            //.padding(.leading, 16)
                            //.padding(.top, 16)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    // Select button in bottom middle (only show if not already selected)
                    if viewModel.selectedPersonaId != persona.id {
                        HStack {
                            Spacer()
                            
                            Button {
                                // Apply persona to user
                                viewModel.applyPersona(persona)
                                dismiss()
                            } label: {
                                HStack {
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    
                                    Text("Select")
                                        .font(.system(size: 20))
                                }
                                .padding() // Add this line
                                .foregroundColor(.primary)
                                .background(.ultraThinMaterial, in: Capsule())
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .onTapGesture {
            dismissKeyboard()
        }
        .onAppear {
            if persona == nil {
                viewModel.loadConfiguration()
            }
            initializeEditingStates()
            triggerInitialSliderAnimation()
        }
        .onDisappear {
            // Skip saving if the persona was deleted in this session
            if !wasDeleted {
                saveAllChanges()
            }
        }
        .onChange(of: editedBaseEmotions) { newEmotions in
            if persona != nil {
                // Auto-save to persona
                guard var updatedPersona = self.persona else { return }
                updatedPersona.baseEmotions = normalizeEmotions(from: newEmotions)
                viewModel.updatePersona(updatedPersona)
            }
        }
        .onChange(of: viewModel.sensitivity) { newSensitivity in
            if persona == nil {
                if editedSensitivity == 0 {
                    editedSensitivity = Double(newSensitivity)
                }
            }
        }
        .onChange(of: editedSensitivity) { newValue in
            if self.persona != nil {
                guard var updatedPersona = self.persona else { return }
                updatedPersona.sensitivity = Int(newValue)
                viewModel.updatePersona(updatedPersona)
            }
        }
        .onChange(of: editedCustomInstructions) { newValue in
            if self.persona != nil {
                guard var updatedPersona = self.persona else { return }
                updatedPersona.customInstructions = newValue
                viewModel.updatePersona(updatedPersona)
            }
        }
        .onChange(of: editedName) { newValue in
            if self.persona != nil {
                guard var updatedPersona = self.persona else { return }
                updatedPersona.name = newValue
                viewModel.updatePersona(updatedPersona)
            }
        }
        .onChange(of: viewModel.baseEmotions) { newEmotions in
            if persona == nil {
                if editedBaseEmotions.isEmpty {
                    editedBaseEmotions = newEmotions
                }
            }
        }
        .onChange(of: viewModel.customInstructions) { newInstructions in
            if persona == nil {
                if editedCustomInstructions.isEmpty {
                    editedCustomInstructions = newInstructions
                }
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func initializeEditingStates() {
        if let persona = persona {
            editedBaseEmotions = persona.baseEmotions
            editedSensitivity = Double(persona.sensitivity)
            editedCustomInstructions = persona.customInstructions
            editedName = persona.name
        } else {
            editedBaseEmotions = viewModel.baseEmotions
            editedSensitivity = Double(viewModel.sensitivity)
            editedCustomInstructions = viewModel.customInstructions
            editedName = name
        }
    }
    
    private func saveAllChanges() {
        if var personaToSave = persona {
            // Save updates to persona doc (do not apply)
            personaToSave.baseEmotions = normalizeEmotions(from: editedBaseEmotions)
            personaToSave.sensitivity = Int(editedSensitivity)
            personaToSave.customInstructions = editedCustomInstructions
            personaToSave.name = editedName
            viewModel.updatePersona(personaToSave)
        } else {
            // Editing live config – previous behaviour
            let normalizedEmotions = normalizeEmotions(from: editedBaseEmotions)
            if normalizedEmotions != viewModel.baseEmotions {
                viewModel.updateBaseEmotions(normalizedEmotions)
            }
            let newSensitivity = Int(editedSensitivity)
            if newSensitivity != viewModel.sensitivity {
                viewModel.updateSensitivity(newSensitivity)
            }
            if editedCustomInstructions != viewModel.customInstructions {
                viewModel.updateCustomInstructions(editedCustomInstructions)
            }
        }
    }
    
    // Normalizes arbitrary integer emotion values so that their total equals 100 while
    // preserving the relative ratios the user set.
    private func normalizeEmotions(from raw: [String: Int]) -> [String: Int] {
        let total = raw.values.reduce(0, +)
        guard total > 0 else { return raw }

        var normalized: [String: Int] = [:]
        var runningTotal = 0
        let emotionOrder = ["Red", "Yellow", "Green", "Blue", "Purple"]

        for (index, emotion) in emotionOrder.enumerated() {
            if index == emotionOrder.count - 1 {
                normalized[emotion] = 100 - runningTotal
            } else {
                let proportion = Double(raw[emotion] ?? 0) / Double(total)
                let value = Int(proportion * 100)
                normalized[emotion] = value
                runningTotal += value
            }
        }

        return normalized
    }
    
    // Adds a dramatic, spring-like animation to the sliders the first time the view appears.
    private func triggerInitialSliderAnimation() {
        // Ensure this runs only once per presentation
        guard !hasRunInitialSliderAnimation else { return }
        hasRunInitialSliderAnimation = true
        
        // Capture the user's configured values
        let targetEmotions = editedBaseEmotions
        let targetSensitivity = editedSensitivity
        
        // Start everything at zero
        editedBaseEmotions = Dictionary(uniqueKeysWithValues: targetEmotions.map { ($0.key, 0) })
        editedSensitivity = 0
        
        // A noticeably slow, overshooting spring (~5 s). Adjust speed/params to fine-tune feel.
        let longSpring = Animation
            .interpolatingSpring(mass: 1, stiffness: 15, damping: 1.8, initialVelocity: 20)
            .speed(0.01)
        
        // Animate to the target values after a slight delay, so the user sees an initial jolt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(longSpring) {
                editedBaseEmotions = targetEmotions
                editedSensitivity = targetSensitivity
            }
        }
    }
}

// MARK: - Sensitivity Configuration Section
struct SensitivityConfigSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var editedSensitivity: Double
    
    // Slow spring used so the slider visibly overshoots then settles (≈5 s)
    private let sliderSpring = Animation.interactiveSpring(response: 5, dampingFraction: 0.15, blendDuration: 0.1)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sensitivity")
                .font(.headline)
            
            Text("This is how quickly and dramatically Auri's emotions change.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(
                value: $editedSensitivity,
                in: 0...100,
                step: 1
            )
            .accentColor(.secondary)
            .animation(sliderSpring, value: editedSensitivity)
            
            if let error = viewModel.configError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if viewModel.isLoadingConfig {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Custom Instructions Configuration Section
struct CustomInstructionsConfigSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var editedCustomInstructions: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions")
                .font(.headline)
            
            Text("This is what guides how Auri behaves and responds to you.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $editedCustomInstructions)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                .frame(minHeight: 200)
            
            if let error = viewModel.configError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if viewModel.isLoadingConfig {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Name Configuration Section
struct NameConfigSection: View {
    @Binding var editedName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name")
                .font(.headline)
            
            TextField("Enter name", text: $editedName)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                .font(.body)
        }
    }
}

// MARK: - Emotions Configuration Section
struct EmotionsConfigSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var editedBaseEmotions: [String: Int]
    
    private let emotionOrder = ["Red", "Yellow", "Green", "Blue", "Purple"]
    
    // Slow spring used so the slider visibly overshoots then settles (≈5 s)
    private let sliderSpring = Animation.interactiveSpring(response: 5, dampingFraction: 0.15, blendDuration: 0.1)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emotions")
                .font(.headline)
            
            Text("These are the emotional values Auri will naturally drift towards.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(emotionOrder, id: \.self) { emotion in
                HStack {
                    Text(emotion)
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)
                    
                    Slider(
                        value: Binding(
                            get: { Double(editedBaseEmotions[emotion] ?? 0) },
                            set: { newValue in
                                editedBaseEmotions[emotion] = Int(newValue)
                            }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .accentColor(.secondary)
                    .animation(sliderSpring, value: editedBaseEmotions[emotion] ?? 0)
                }
            }
            
            if let error = viewModel.configError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if viewModel.isLoadingConfig {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    EditView(
        viewModel: {
            let mockViewModel = ChatViewModel()
            
            // Set up mock data for preview
            mockViewModel.baseEmotions = [
                "Red": 5,
                "Yellow": 20,
                "Green": 30,
                "Blue": 40,
                "Purple": 5
            ]
            
            mockViewModel.sensitivity = 65
            
            return mockViewModel
        }(),
        persona: SocialAIService.Persona(
            id: "mock-persona-id",
            name: "Energetic Friend",
            baseEmotions: [
                "Red": 10,
                "Yellow": 35,
                "Green": 25,
                "Blue": 15,
                "Purple": 15
            ],
            sensitivity: 75,
            customInstructions: "Be upbeat, encouraging, and always ready to help with enthusiasm!"
        ),
        name: "Energetic Friend"
    )
    .environmentObject({
        let mockAuth = AuthViewModel()
        return mockAuth
    }())
}
