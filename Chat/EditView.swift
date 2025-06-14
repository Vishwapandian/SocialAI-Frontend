import SwiftUI

struct EditView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChatViewModel
    var persona: SocialAIService.Persona? = nil // nil means editing user config

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // State variables for the aura
    @State private var previewEmotions: [String: Int] = [:]
    @State private var animateGradient = false
    
    // State variables for editing (always in edit mode now)
    @State private var editedBaseEmotions: [String: Int] = [:]
    @State private var editedSensitivity: Double = 0
    @State private var editedCustomInstructions: String = "" // Editable field for future use
    

    
    // State used to drive the first-open "rubber-band" slider animation
    @State private var hasRunInitialSliderAnimation: Bool = false
    
    // Emotion to Color Mapping and default color (same as ChatView)
    static let emotionColorMapping: [String: Color] = [
        "Yellow": .yellow,
        "Blue": .blue,
        "Red": .red,
        "Purple": .purple,
        "Green": .green
    ]
    static let defaultAuraColor: Color = Color.clear
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    // Emotions Configuration Section with Aura Preview
                    VStack(spacing: 16) {
                        
                        // Small Aura Preview
                        AuraPreviewView(emotions: previewEmotions)
                            .animation(.easeInOut(duration: 3), value: animateGradient)
                        
                        EmotionsConfigSection(
                            viewModel: viewModel,
                            editedBaseEmotions: $editedBaseEmotions,
                            onEmotionsChange: { newEmotions in
                                self.previewEmotions = newEmotions
                                animateGradient.toggle()
                            }
                        )
                    }
                    
                    Divider()
                    
                    // Sensitivity Configuration Section
                    SensitivityConfigSection(viewModel: viewModel, editedSensitivity: $editedSensitivity)
                    
                    Divider()
                    
                    // Custom Instructions Configuration Section
                    CustomInstructionsConfigSection(viewModel: viewModel, editedCustomInstructions: $editedCustomInstructions)
                    
                    // Select/Delete Buttons if editing a persona
                    if let persona = persona {
                        HStack {
                            Button(role: .destructive) {
                                viewModel.deletePersona(personaId: persona.id ?? "") {
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                            }
                            Spacer()
                            Button {
                                // Apply persona to user
                                viewModel.applyPersona(persona)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("Select")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(
                colorScheme == .light 
                    ? Color(red: 240/255, green: 240/255, blue: 240/255)
                    : Color.clear
            )
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
                saveAllChanges()
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
            .onChange(of: viewModel.baseEmotions) { newEmotions in
                if persona == nil {
                    if editedBaseEmotions.isEmpty {
                        editedBaseEmotions = newEmotions
                        self.previewEmotions = newEmotions
                        animateGradient.toggle()
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
            previewEmotions = persona.baseEmotions
        } else {
            editedBaseEmotions = viewModel.baseEmotions
            editedSensitivity = Double(viewModel.sensitivity)
            editedCustomInstructions = viewModel.customInstructions
            previewEmotions = viewModel.baseEmotions
        }
        animateGradient.toggle()
    }
    
    private func saveAllChanges() {
        if var personaToSave = persona {
            // Save updates to persona doc (do not apply)
            personaToSave.baseEmotions = normalizeEmotions(from: editedBaseEmotions)
            personaToSave.sensitivity = Int(editedSensitivity)
            personaToSave.customInstructions = editedCustomInstructions
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
        previewEmotions = editedBaseEmotions
        
        // A noticeably slow, overshooting spring (~5 s). Adjust speed/params to fine-tune feel.
        let longSpring = Animation
            .interpolatingSpring(mass: 1, stiffness: 15, damping: 1.8, initialVelocity: 20)
            .speed(0.01)
        
        // Animate to the target values after a slight delay, so the user sees an initial jolt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(longSpring) {
                editedBaseEmotions = targetEmotions
                editedSensitivity = targetSensitivity
                previewEmotions = targetEmotions
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Aura Preview
struct AuraPreviewView: View {
    let emotions: [String: Int]
    
    private let emotionColorMapping = EditView.emotionColorMapping
    private let defaultAuraColor = EditView.defaultAuraColor

    var body: some View {
        RadialGradient(
            gradient: createAuraGradient(),
            center: .center,
            startRadius: 0,
            endRadius: 75
        )
        .compositingGroup()
        .blur(radius: 15)
        .frame(width: 200, height: 200)
    }

    private func createAuraGradient() -> Gradient {
        let activeSortedEmotions = emotions
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }

        if activeSortedEmotions.isEmpty {
            return Gradient(stops: [
                .init(color: defaultAuraColor, location: 0.0),
                .init(color: .clear, location: 1.0)
            ])
        }
        
        if activeSortedEmotions.count == 1, let emotion = activeSortedEmotions.first {
            let color = emotionColorMapping[emotion.key] ?? defaultAuraColor
            return Gradient(stops: [
                .init(color: color, location: 0.0),
                .init(color: color, location: 0.4),
                .init(color: .clear, location: 1.0)
            ])
        }

        let totalIntensity = CGFloat(activeSortedEmotions.reduce(0) { $0 + $1.value })
        guard totalIntensity > 0 else {
            return Gradient(stops: [
                .init(color: defaultAuraColor, location: 0.0),
                .init(color: .clear, location: 1.0)
            ])
        }

        let coloredPortion: CGFloat = 0.7
        var stops: [Gradient.Stop] = []
        var cumulativeProportion: CGFloat = 0.0

        for i in 0..<activeSortedEmotions.count {
            let emotionEntry = activeSortedEmotions[i]
            let color = emotionColorMapping[emotionEntry.key] ?? defaultAuraColor
            
            if i == 0 {
                stops.append(Gradient.Stop(color: color, location: 0.0))
            }
            
            let intensity = CGFloat(emotionEntry.value)
            cumulativeProportion += intensity / totalIntensity
            let location = cumulativeProportion * coloredPortion
            
            stops.append(Gradient.Stop(color: color, location: min(location, coloredPortion)))
        }
        
        // Add a smoother, hue-preserving fade-out instead of jumping to transparent black
        if let lastStop = stops.last {
            stops.append(.init(color: lastStop.color.opacity(0.4), location: 0.85))
            stops.append(.init(color: lastStop.color.opacity(0.0), location: 1.0))
        } else {
            stops.append(.init(color: .clear, location: 1.0))
        }
        
        // Cleanup duplicate stops to ensure a smooth gradient
        if stops.count > 1 {
            var uniqueStops: [Gradient.Stop] = [stops[0]]
            for j in 1..<stops.count {
                if !(uniqueStops.last!.color == stops[j].color && uniqueStops.last!.location == stops[j].location) {
                    uniqueStops.append(stops[j])
                }
            }
            stops = uniqueStops
        }

        return Gradient(stops: stops)
    }
}

// MARK: - Individual Emotion Aura
struct EmotionAuraView: View {
    let emotion: String
    
    private let emotionColorMapping = EditView.emotionColorMapping
    private let defaultAuraColor = EditView.defaultAuraColor
    
    var body: some View {
        let color = emotionColorMapping[emotion] ?? defaultAuraColor
        
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: color, location: 0.0),
                        .init(color: color.opacity(0.8), location: 0.4),
                        .init(color: color.opacity(0.2), location: 0.8),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 20
                )
            )
            .blur(radius: 8)
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

// MARK: - Emotions Configuration Section
struct EmotionsConfigSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var editedBaseEmotions: [String: Int]
    let onEmotionsChange: ([String: Int]) -> Void
    
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
                    // Small emotion aura preview
                    EmotionAuraView(emotion: emotion)
                        .frame(width: 40, height: 40)
                    
                    Slider(
                        value: Binding(
                            get: { Double(editedBaseEmotions[emotion] ?? 0) },
                            set: { newValue in
                                editedBaseEmotions[emotion] = Int(newValue)
                                onEmotionsChange(editedBaseEmotions)
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
    EditView(viewModel: {
        let mockViewModel = ChatViewModel()
        
        // Set up mock data for preview
        mockViewModel.baseEmotions = [
            "Red": 5,
            "Yellow": 20,
            "Green": 30,
            "Blue": 40,
            "Purple": 5
        ]
        
        // Custom instructions are editable but show placeholder content
        
        mockViewModel.sensitivity = 65
        
        return mockViewModel
    }())
    .environmentObject({
        let mockAuth = AuthViewModel()
        return mockAuth
    }())
}
