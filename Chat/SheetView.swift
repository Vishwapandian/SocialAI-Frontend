import SwiftUI

struct SheetView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: ChatViewModel
    @State private var showingSignOutConfirmation = false
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Quick Actions Tab
                QuickActionsView(viewModel: viewModel, dismiss: dismiss)
                    .tabItem {
                        Image(systemName: "bolt.fill")
                        Text("Quick")
                    }
                    .tag(0)
                
                // Memory Configuration Tab
                MemoryConfigView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("Memory")
                    }
                    .tag(1)
                
                // Base Emotions Tab
                BaseEmotionsView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "heart.fill")
                        Text("Emotions")
                    }
                    .tag(2)
            }
            .navigationTitle("AI Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
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
    }
}

// MARK: - Quick Actions Tab
struct QuickActionsView: View {
    @ObservedObject var viewModel: ChatViewModel
    let dismiss: DismissAction
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Button("Get Emotional State") {
                viewModel.requestEmotionDisplay()
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            
            Button("Reset Auri", role: .destructive) {
                viewModel.resetMemoryAndChat()
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Memory Configuration Tab
struct MemoryConfigView: View {
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
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Base Emotions Configuration Tab
struct BaseEmotionsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var editedBaseEmotions: [String: Int] = [:]
    @State private var isEditing: Bool = false
    
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
                    }
                    .foregroundColor(.secondary)
                    
                    Button("Save") {
                        viewModel.updateBaseEmotions(editedBaseEmotions)
                        isEditing = false
                    }
                    .disabled(viewModel.isLoadingConfig || !isValidEmotionSum)
                } else {
                    Button("Edit") {
                        editedBaseEmotions = viewModel.baseEmotions
                        isEditing = true
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
            
            Spacer()
        }
        .padding()
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