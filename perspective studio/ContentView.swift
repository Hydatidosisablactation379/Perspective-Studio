import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainView()
        } else {
            OnboardingContainerView {
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Main View

enum SidebarTab: String, CaseIterable, Identifiable {
    case discover
    case chat
    case downloads
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: "Discover"
        case .chat: "Chat"
        case .downloads: "Downloads"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .discover: "sparkle.magnifyingglass"
        case .chat: "bubble.left.and.bubble.right"
        case .downloads: "arrow.down.circle"
        case .settings: "gearshape"
        }
    }

    var shortcutNumber: Int {
        switch self {
        case .discover: 1
        case .chat: 2
        case .downloads: 3
        case .settings: 4
        }
    }

    var keyEquivalent: KeyEquivalent {
        switch self {
        case .discover: "1"
        case .chat: "2"
        case .downloads: "3"
        case .settings: "4"
        }
    }
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var chatViewModel = ChatViewModel()
    @State private var selectedTab: SidebarTab = .discover

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                if selectedTab == .chat {
                    ConversationListView(
                        selectedConversation: $chatViewModel.selectedConversation,
                        modelState: chatViewModel.modelState,
                        onNewChat: { chatViewModel.createConversation(in: modelContext) },
                        onDelete: { chatViewModel.deleteConversation($0, in: modelContext) }
                    )
                }

                Divider()

                HStack(spacing: 0) {
                    ForEach(SidebarTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tab.symbol)
                                    .font(.system(size: 16))
                                Text("\(tab.title)  \u{2318}\(tab.shortcutNumber)")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(tab.keyEquivalent, modifiers: .command)
                        .accessibilityLabel("\(tab.title), Command \(tab.shortcutNumber)")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            switch selectedTab {
            case .chat:
                if let conversation = chatViewModel.selectedConversation {
                    ChatDetailView(conversation: conversation, chatViewModel: chatViewModel)
                } else {
                    ContentUnavailableView("Select a Conversation", systemImage: "bubble.left")
                }
            case .discover:
                ModelDiscoveryView(models: chatViewModel.availableModels, chatViewModel: chatViewModel)
            case .downloads:
                DownloadsView(chatViewModel: chatViewModel)
            case .settings:
                SettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay {
            Button("New Chat") {
                selectedTab = .chat
                chatViewModel.createConversation(in: modelContext)
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
        }
        .onChange(of: chatViewModel.selectedConversation) {
            Task { await LLMService.shared.resetSession() }
        }
        .task {
            await chatViewModel.fetchModels()
        }
    }
}
