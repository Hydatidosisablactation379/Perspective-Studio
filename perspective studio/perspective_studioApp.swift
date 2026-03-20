import SwiftUI
import SwiftData

@main
struct perspective_studioApp: App {
    @State private var selectedTab: SidebarTab = .discover
    @State private var chatViewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab, chatViewModel: chatViewModel)
        }
        .modelContainer(for: [UserProfile.self, Conversation.self, Message.self])
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    selectedTab = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("New Chat") {
                    selectedTab = .chat
                    // Create conversation is deferred to MainView via onChange
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                ForEach(SidebarTab.allCases) { tab in
                    Button("Go to \(tab.title)") {
                        selectedTab = tab
                    }
                    .keyboardShortcut(tab.keyEquivalent, modifiers: .command)
                }
            }
        }
    }
}
