import SwiftUI

struct SheetView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChatViewModel
    @State private var showingSignOutConfirmation = false
    @State private var showingResetConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // State variables for the aura
    @State private var previewEmotions: [String: Int] = [:]
    @State private var animateGradient = false
    
    // State variables for editing (always in edit mode now)
    @State private var editedBaseEmotions: [String: Int] = [:]
    @State private var editedSensitivity: Double = 0
    @State private var editedMemory: String = ""
    
    // Emotion to Color Mapping and default color (same as ChatView)
    static let emotionColorMapping: [String: Color] = [
        "Yellow": .yellow,
        "Blue": .blue,
        "Red": .red,
        "Purple": .purple,
        "Green": .green
    ]
    static let defaultAuraColor: Color = Color.gray
    
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
                    
                    // Memory Configuration Section
                    MemoryConfigSection(viewModel: viewModel, editedMemory: $editedMemory)
                    
                    Divider()
                    
                    // Reset Section
                    VStack(spacing: 16) {
                        Button("Reset Auri", role: .destructive) {
                            showingResetConfirmation = true
                        }
                        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.red)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                        
                        Button("Sign Out") {
                            showingSignOutConfirmation = true
                        }
                        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .onTapGesture {
                dismissKeyboard()
            }
            .onAppear {
                viewModel.loadConfiguration()
                initializeEditingStates()
            }
            .onDisappear {
                saveAllChanges()
            }
            .onChange(of: viewModel.baseEmotions) { newEmotions in
                if editedBaseEmotions.isEmpty {
                    editedBaseEmotions = newEmotions
                    self.previewEmotions = newEmotions
                    animateGradient.toggle()
                }
            }
            .onChange(of: viewModel.sensitivity) { newSensitivity in
                if editedSensitivity == 0 {
                    editedSensitivity = Double(newSensitivity)
                }
            }
            .onChange(of: viewModel.aiMemory) { newMemory in
                if editedMemory.isEmpty {
                    editedMemory = newMemory
                }
            }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                saveAllChanges()
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
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func initializeEditingStates() {
        editedBaseEmotions = viewModel.baseEmotions
        editedSensitivity = Double(viewModel.sensitivity)
        editedMemory = viewModel.aiMemory
        previewEmotions = viewModel.baseEmotions
        animateGradient.toggle()
    }
    
    private func saveAllChanges() {
        // Save emotions
        let normalizedEmotions = normalizeEmotions(from: editedBaseEmotions)
        viewModel.updateBaseEmotions(normalizedEmotions)
        
        // Save sensitivity
        viewModel.updateSensitivity(Int(editedSensitivity))
        
        // Save memory
        viewModel.updateMemory(editedMemory)
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
}

// MARK: - Aura Preview
struct AuraPreviewView: View {
    let emotions: [String: Int]
    
    private let emotionColorMapping = SheetView.emotionColorMapping
    private let defaultAuraColor = SheetView.defaultAuraColor

    var body: some View {
        RadialGradient(
            gradient: createAuraGradient(),
            center: .center,
            startRadius: 0,
            endRadius: 75
        )
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

        let coloredPortion: CGFloat = 0.9
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
        
        stops.append(.init(color: .clear, location: 1.0))
        
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
    
    private let emotionColorMapping = SheetView.emotionColorMapping
    private let defaultAuraColor = SheetView.defaultAuraColor
    
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

// MARK: - Memory Configuration Section
struct MemoryConfigSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var editedMemory: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory")
                .font(.headline)
            
            TextEditor(text: $editedMemory)
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
    SheetView(viewModel: {
        let mockViewModel = ChatViewModel()
        
        // Set up mock data for preview
        mockViewModel.baseEmotions = [
            "Red": 5,
            "Yellow": 20,
            "Green": 30,
            "Blue": 40,
            "Purple": 5
        ]
        
        mockViewModel.aiMemory = """
        I am Auri, your AI companion. I remember that you enjoy discussing technology and creative projects. You've mentioned being interested in SwiftUI development and building intuitive user interfaces. I aim to be helpful, empathetic, and engaging in our conversations.
        """
        
        mockViewModel.sensitivity = 65
        
        return mockViewModel
    }())
    .environmentObject({
        let mockAuth = AuthViewModel()
        return mockAuth
    }())
} 
