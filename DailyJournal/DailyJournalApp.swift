import SwiftUI
import SwiftData

@main
struct DailyJournalApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppLog.start()
    }

    @StateObject private var appLock = AppLock.shared

    let container: ModelContainer = {
        let schema = Schema([JournalEntry.self, MediaItem.self, UserProfile.self])
        // .automatic uses the iCloud container from the entitlements file,
        // so entries sync across the user's devices.
        // Settings > Backup can turn iCloud sync off; it applies the next time the app opens.
        let iCloudOn = UserDefaults.standard.object(forKey: "iCloudSyncOn") as? Bool ?? true
        AppLog.info("iCloud sync \(iCloudOn ? "on" : "off")")
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: iCloudOn ? .automatic : .none)
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
                .task {
                    appLock.lockIfEnabled()
                    BackupManager.shared.container = container
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            AppLog.info("App is \(phase == .active ? "active" : phase == .background ? "in background" : "inactive"), memory \(AppLog.memoryMB()) MB")
            appLock.handle(phase)
            if phase == .background { BackupManager.shared.autoBackupIfNeeded() }
        }
    }
}
