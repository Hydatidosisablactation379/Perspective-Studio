import SwiftUI
import SwiftData

@main
struct perspective_studioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [UserProfile.self, Conversation.self, Message.self])
    }
}
