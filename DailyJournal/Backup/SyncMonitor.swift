import Foundation
import CoreData

/// Remembers when iCloud last finished syncing, from Core Data's CloudKit events
/// (SwiftData syncs through the same system).
@MainActor
final class SyncMonitor: ObservableObject {
    static let shared = SyncMonitor()

    @Published private(set) var lastICloudSync: Date? = UserDefaults.standard.object(forKey: "lastICloudSync") as? Date

    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type != .setup, let end = event.endDate else { return }
            let ok = event.succeeded
            MainActor.assumeIsolated {
                if ok {
                    SyncMonitor.shared.lastICloudSync = end
                    UserDefaults.standard.set(end, forKey: "lastICloudSync")
                } else {
                    AppLog.info("iCloud sync event failed: \(event.error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
}
