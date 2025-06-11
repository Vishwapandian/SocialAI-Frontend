import SwiftUI

struct SheetView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChatViewModel
    @State private var showingSignOutConfirmation = false
    @State private var showingResetConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // State variables for the aura gradient
    @State private var gradientStops: [Gradient.Stop] = [
        Gradient.Stop(color: Self.defaultAuraColor, location: 0),
        Gradient.Stop(color: Self.defaultAuraColor, location: 1)
    ]
    @State private var animateGradient = false
    
    // Emotion to Color Mapping and default color (same as ChatView)
    static let emotionColorMapping: [String: Color] = [
        "Yellow": .yellow,
        "Blue": .blue,
        "Red": .red,
        "Purple": .purple,
        "Green": .green
    ]
    static let defaultAuraColor: Color = Color.gray.opacity(0.3)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Memory Configuration Section
                    MemoryConfigSection(viewModel: viewModel)
                    
                    Divider()
                    
                    // Emotions Configuration Section with Aura Preview
                    VStack(spacing: 16) {
                        EmotionsConfigSection(
                            viewModel: viewModel,
                            onEditingStateChange: { isEditing, editedEmotions in
                                if isEditing {
                                    updateGradientStops(from: editedEmotions)
                                } else {
                                    updateGradientStops(from: viewModel.baseEmotions)
                                }
                                animateGradient.toggle()
                            }
                        )
                        
                        // Small Aura Preview
                        VStack(spacing: 8) {
                            Text("Aura Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            RadialGradient(
                                gradient: Gradient(stops: gradientStops),
                                center: .center,
                                startRadius: 10,
                                endRadius: 50
                            )
                            .blur(radius: 15)
                            .animation(.easeInOut(duration: 3), value: animateGradient)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        }
                    }
                    
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
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSignOutConfirmation = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                viewModel.loadConfiguration()
                updateGradientStops(from: viewModel.baseEmotions)
                animateGradient.toggle()
            }
            .onChange(of: viewModel.baseEmotions) { newEmotions in
                updateGradientStops(from: newEmotions)
                animateGradient.toggle()
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
}

// MARK: - Aura Gradient Logic
extension SheetView {
    private func updateGradientStops(from emotions: [String: Int]) {
        guard !emotions.isEmpty else {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        let activeSortedEmotions = emotions
            .sorted { $0.value > $1.value }

        if activeSortedEmotions.isEmpty {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        if activeSortedEmotions.count == 1 {
            let emotion = activeSortedEmotions[0]
            let color = Self.emotionColorMapping[emotion.key] ?? Self.defaultAuraColor
            self.gradientStops = [
                Gradient.Stop(color: color, location: 0),
                Gradient.Stop(color: color, location: 1)
            ]
            return
        }

        let totalIntensity = CGFloat(activeSortedEmotions.reduce(0) { $0 + $1.value })
        guard totalIntensity > 0 else {
            self.gradientStops = [
                Gradient.Stop(color: Self.defaultAuraColor, location: 0),
                Gradient.Stop(color: Self.defaultAuraColor, location: 1)
            ]
            return
        }

        var newStops: [Gradient.Stop] = []
        var cumulativeProportion: CGFloat = 0.0

        for i in 0..<activeSortedEmotions.count {
            let emotionEntry = activeSortedEmotions[i]
            let color = Self.emotionColorMapping[emotionEntry.key] ?? Self.defaultAuraColor
            
            if i == 0 {
                newStops.append(Gradient.Stop(color: color, location: 0.0))
            }
            
            let intensity = CGFloat(emotionEntry.value)
            cumulativeProportion += intensity / totalIntensity
            let locationForThisColorSegmentEnd = min(cumulativeProportion, 1.0)
            
            newStops.append(Gradient.Stop(color: color, location: locationForThisColorSegmentEnd))
        }

        if newStops.count > 1 {
            var uniqueStops: [Gradient.Stop] = [newStops[0]]
            for j in 1..<newStops.count {
                let lastAddedStop = uniqueStops.last!
                let currentStopToConsider = newStops[j]
                if !(currentStopToConsider.color == lastAddedStop.color && currentStopToConsider.location == lastAddedStop.location) {
                    uniqueStops.append(currentStopToConsider)
                }
            }
            newStops = uniqueStops
        }
        
        if newStops.count == 1, let firstStop = newStops.first {
             newStops.append(Gradient.Stop(color: firstStop.color, location: 1.0))
        }

        self.gradientStops = newStops.isEmpty ? [
            Gradient.Stop(color: Self.defaultAuraColor, location: 0),
            Gradient.Stop(color: Self.defaultAuraColor, location: 1)
        ] : newStops
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
