import SwiftUI
import SwiftData

@main
struct DailyJournalApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppLog.start()
    }

    let container: ModelContainer = {
        let schema = Schema([JournalEntry.self, MediaItem.self, UserProfile.self])
        // .automatic uses the iCloud container from the entitlements file,
        // so entries sync across the user's devices.
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            AppLog.error("Could not create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .appAppearance()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            AppLog.info("App is \(phase == .active ? "active" : phase == .background ? "in background" : "inactive"), memory \(AppLog.memoryMB()) MB")
        }
    }
}
