import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        NavigationStack {
            content
        }
        .onAppear {
            selectedDate = Date()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if let conversation = findOrCreateConversation(for: selectedDate, context: modelContext) {
            let calendar = Calendar.current
            let today = Date()
            let startOfToday = calendar.startOfDay(for: today)
            let isToday = calendar.isDate(conversation.createdAt, equalTo: startOfToday, toGranularity: .day)
            
            if isToday {
                let viewModel = ChatViewModel(modelContext: modelContext, conversation: conversation)
                ChatView(viewModel: viewModel)
            } else {
                Color.clear
                    .onAppear {
                        selectedDate = today
                    }
            }
        } else {
            Text("Failed to load or create conversation.")
        }
    }
    
    private func findOrCreateConversation(for date: Date, context: ModelContext) -> Conversation? {
        let calendar = Calendar.current
        guard let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date),
              let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) else {
            return nil
        }

        let fetchDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate<Conversation> { conversation in
                conversation.createdAt >= startOfDay && conversation.createdAt <= endOfDay
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            if let existingConversation = try context.fetch(fetchDescriptor).first {
                return existingConversation
            }
        } catch {
            print("Failed to fetch conversations: \(error)")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let newConversation = Conversation(
            title: "\(dateFormatter.string(from: date))",
            createdAt: startOfDay,
            updatedAt: startOfDay
        )

        context.insert(newConversation)
        return newConversation
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
