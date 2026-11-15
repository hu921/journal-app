import Foundation
import CoreData

/// Remembers when iCloud last finished syncing, from Core Data's CloudKit events
/// (SwiftData syncs through the same system).
@MainActor
final class SyncMonitor: ObservableObject {
    static let shared = SyncMonitor()

    @Published private(set) var lastICloudSync: Date? = UserDefaults.standard.object(forKey: "lastICloudSync") as? Date

    /// When the last successful iCloud upload (export) finished.
    private(set) var lastExport: Date?

    private var observer: NSObjectProtocol?

    /// Waits until iCloud finishes an upload that ends after `since`, up to `timeout` seconds.
    /// Used so Google Drive backs up after iCloud.
    func waitForICloudUpload(since: Date, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let lastExport, lastExport >= since { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type != .setup, let end = event.endDate else { return }
            let ok = event.succeeded
            let isExport = event.type == .export
            MainActor.assumeIsolated {
                if ok && isExport { SyncMonitor.shared.lastExport = end }
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
