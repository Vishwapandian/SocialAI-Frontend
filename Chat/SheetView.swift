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
                            onEditingStateChange: { isEditing, editedEmotions in
                                if isEditing {
                                    self.previewEmotions = editedEmotions
                                } else {
                                    self.previewEmotions = viewModel.baseEmotions
                                }
                                animateGradient.toggle()
                            }
                        )
                    }
                    
                    Divider()
                    
                    // Memory Configuration Section
                    MemoryConfigSection(viewModel: viewModel)
                    
                    Divider()
                    
                    // Reset Section
                    VStack(spacing: 16) {
                        Button("Reset Auri", role: .destructive) {
                            showingResetConfirmation = true
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        
                        Button("Sign Out") {
                            showingSignOutConfirmation = true
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .onAppear {
                viewModel.loadConfiguration()
                self.previewEmotions = viewModel.baseEmotions
                animateGradient.toggle()
            }
            .onChange(of: viewModel.baseEmotions) { newEmotions in
                self.previewEmotions = newEmotions
                animateGradient.toggle()
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
}

// MARK: - Aura Preview
struct AuraPreviewView: View {
    let emotions: [String: Int]
    
    private let emotionColorMapping = SheetView.emotionColorMapping
    private let defaultAuraColor = SheetView.defaultAuraColor

    var body: some View {
        ZStack {
            let activeEmotions = emotions.filter { $0.value > 0 }

            if activeEmotions.isEmpty {
                let gradient = Gradient(stops: [
                    .init(color: defaultAuraColor, location: 0.0),
                    .init(color: defaultAuraColor, location: 0.3),
                    .init(color: .clear, location: 1.0)
                ])
                RadialGradient(
                    gradient: gradient,
                    center: .center,
                    startRadius: 0,
                    endRadius: 20
                )
                .blur(radius: 10)
            } else {
                let sortedEmotions = activeEmotions.sorted { $0.key < $1.key }
                
                ForEach(sortedEmotions, id: \.key) { key, value in
                    let color = emotionColorMapping[key] ?? defaultAuraColor
                    let intensity = CGFloat(value) / 100.0
                    
                    let coreSize: CGFloat = 0.3
                    let gradient = Gradient(stops: [
                        .init(color: color, location: 0.0),
                        .init(color: color, location: coreSize),
                        .init(color: .clear, location: 1.0)
                    ])

                    RadialGradient(
                        gradient: gradient,
                        center: .center,
                        startRadius: 0,
                        endRadius: 15 + 35 * intensity
                    )
                    .blur(radius: 15)
                }
            }
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Memory Configuration Section
struct MemoryConfigSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var editedMemory: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Memory")
                    .font(.headline)
                
                Spacer()
                
                if isEditing {
                    Button("Cancel") {
                        editedMemory = viewModel.aiMemory
                        isEditing = false
                    }
                    .foregroundColor(.secondary)
                    
                    Button("Save") {
                        viewModel.updateMemory(editedMemory)
                        isEditing = false
                    }
                    .disabled(viewModel.isLoadingConfig)
                } else {
                    Button("Edit") {
                        editedMemory = viewModel.aiMemory
                        isEditing = true
                    }
                    .disabled(viewModel.isLoadingConfig)
                }
            }
            
            if isEditing {
                TextEditor(text: $editedMemory)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(minHeight: 200)
            } else {
                ScrollView {
                    Text(viewModel.aiMemory.isEmpty ? "No memory stored yet." : viewModel.aiMemory)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 200)
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

// MARK: - Emotions Configuration Section
struct EmotionsConfigSection: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var editedBaseEmotions: [String: Int] = [:]
    @State private var isEditing: Bool = false
    
    let onEditingStateChange: (Bool, [String: Int]) -> Void
    
    private let emotionOrder = ["Red", "Yellow", "Green", "Blue", "Purple"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Emotions")
                    .font(.headline)
                
                Spacer()
                
                if isEditing {
                    Button("Cancel") {
                        editedBaseEmotions = viewModel.baseEmotions
                        isEditing = false
                        onEditingStateChange(false, viewModel.baseEmotions)
                    }
                    .foregroundColor(.secondary)
                    
                    Button("Save") {
                        viewModel.updateBaseEmotions(editedBaseEmotions)
                        isEditing = false
                        onEditingStateChange(false, editedBaseEmotions)
                    }
                    .disabled(viewModel.isLoadingConfig || !isValidEmotionSum)
                } else {
                    Button("Edit") {
                        editedBaseEmotions = viewModel.baseEmotions
                        isEditing = true
                        onEditingStateChange(true, editedBaseEmotions)
                    }
                    .disabled(viewModel.isLoadingConfig)
                }
            }
            
            Text("Set the emotional values for your AI. These will be used as both the current state and the homeostasis target.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            let emotions = isEditing ? editedBaseEmotions : viewModel.baseEmotions
            
            ForEach(emotionOrder, id: \.self) { emotion in
                HStack {
                    Text(emotion)
                        .frame(width: 60, alignment: .leading)
                    
                    if isEditing {
                        Slider(
                            value: Binding(
                                get: { Double(editedBaseEmotions[emotion] ?? 0) },
                                set: { newValue in
                                    editedBaseEmotions[emotion] = Int(newValue)
                                    normalizeBaseEmotions()
                                    onEditingStateChange(true, editedBaseEmotions)
                                }
                            ),
                            in: 0...100,
                            step: 1
                        )
                        
                        Text("\(editedBaseEmotions[emotion] ?? 0)")
                            .frame(width: 30)
                            .font(.caption)
                    } else {
                        ProgressView(value: Double(emotions[emotion] ?? 0), total: 100)
                        
                        Text("\(emotions[emotion] ?? 0)")
                            .frame(width: 30)
                            .font(.caption)
                    }
                }
            }
            
            if isEditing {
                let total = editedBaseEmotions.values.reduce(0, +)
                HStack {
                    Text("Total: \(total)")
                        .font(.caption)
                        .foregroundColor(total == 100 ? .green : .red)
                    
                    Spacer()
                    
                    if total != 100 {
                        Button("Normalize") {
                            normalizeBaseEmotions()
                            onEditingStateChange(true, editedBaseEmotions)
                        }
                        .font(.caption)
                    }
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
    
    private var isValidEmotionSum: Bool {
        editedBaseEmotions.values.reduce(0, +) == 100
    }
    
    private func normalizeBaseEmotions() {
        let total = editedBaseEmotions.values.reduce(0, +)
        guard total > 0 else { return }
        
        var normalized: [String: Int] = [:]
        var runningTotal = 0
        
        for (index, emotion) in emotionOrder.enumerated() {
            if index == emotionOrder.count - 1 {
                // Last emotion gets the remainder to ensure total is exactly 100
                normalized[emotion] = 100 - runningTotal
            } else {
                let normalizedValue = Int(Double(editedBaseEmotions[emotion] ?? 0) / Double(total) * 100)
                normalized[emotion] = normalizedValue
                runningTotal += normalizedValue
            }
        }
        
        editedBaseEmotions = normalized
    }
}

#Preview {
    SheetView(viewModel: {
        let mockViewModel = ChatViewModel()
        
        // Set up mock data for preview
        mockViewModel.baseEmotions = [
            "Red": 20,
            "Yellow": 25,
            "Green": 15,
            "Blue": 30,
            "Purple": 10
        ]
        
        mockViewModel.aiMemory = """
        I am Auri, your AI companion. I remember that you enjoy discussing technology and creative projects. You've mentioned being interested in SwiftUI development and building intuitive user interfaces. I aim to be helpful, empathetic, and engaging in our conversations.
        """
        
        return mockViewModel
    }())
    .environmentObject({
        let mockAuth = AuthViewModel()
        return mockAuth
    }())
} 

