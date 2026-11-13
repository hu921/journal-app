import SwiftUI
import SwiftData

@main
struct DailyJournalApp: App {
    let container: ModelContainer = {
        let schema = Schema([JournalEntry.self, MediaItem.self, UserProfile.self])
        // .automatic uses the iCloud container from the entitlements file,
        // so entries sync across the user's devices.
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
