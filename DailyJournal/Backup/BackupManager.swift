import SwiftUI
import SwiftData
import UIKit

/// Backs up the whole journal to Google Drive as a .zip (the same file as
/// Export > Full Backup with Photos), and restores from one.
/// Automatic backups run when the app goes to the background and there are new entries.
@MainActor
final class BackupManager: ObservableObject {
    static let shared = BackupManager()

    /// Keep this many backups on Drive; older ones are deleted.
    static let keepCount = 5

    @Published var isOn = UserDefaults.standard.bool(forKey: "googleBackupOn") {
        didSet { UserDefaults.standard.set(isOn, forKey: "googleBackupOn") }
    }
    @Published private(set) var isWorking = false
    @Published private(set) var status: String?
    @Published private(set) var lastBackup: Date? = UserDefaults.standard.object(forKey: "googleLastBackup") as? Date
    @Published var lastError: String?

    var container: ModelContainer?

    private var lastFingerprint: String {
        get { UserDefaults.standard.string(forKey: "googleLastFingerprint") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "googleLastFingerprint") }
    }

    /// Changes when entries or photos are added or removed.
    private func fingerprint() -> String {
        guard let container else { return "" }
        let context = ModelContext(container)
        let entries = (try? context.fetchCount(FetchDescriptor<JournalEntry>())) ?? 0
        let media = (try? context.fetchCount(FetchDescriptor<MediaItem>())) ?? 0
        return "\(entries)-\(media)"
    }

    var hasNewEntries: Bool { fingerprint() != lastFingerprint }

    // MARK: Turn on / off

    func turnOn() async {
        lastError = nil
        do {
            if !GoogleAuth.shared.isSignedIn { try await GoogleAuth.shared.signIn() }
            isOn = true
            await backUpNow()
        } catch {
            isOn = false
            if let auth = error as? GoogleAuth.AuthError, case .cancelled = auth { return }
            lastError = error.localizedDescription
        }
    }

    func turnOff(signOut: Bool) {
        isOn = false
        if signOut { GoogleAuth.shared.signOut() }
    }

    // MARK: Backup

    /// Called when the app goes to the background.
    func autoBackupIfNeeded() {
        guard isOn, GoogleAuth.shared.isSignedIn, !isWorking, hasNewEntries else { return }
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "Google Drive backup") {
            UIApplication.shared.endBackgroundTask(taskID)
        }
        let leftAt = Date()
        Task {
            // Both on: iCloud first. Give iCloud up to 10 seconds to upload, then Google Drive.
            if UserDefaults.standard.object(forKey: "iCloudSyncOn") as? Bool ?? true {
                await SyncMonitor.shared.waitForICloudUpload(since: leftAt, timeout: 10)
            }
            await backUpNow(automatic: true)
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }

    func backUpNow(automatic: Bool = false) async {
        guard let container, !isWorking else { return }
        isWorking = true
        status = "Preparing backup…"
        lastError = nil
        defer { isWorking = false; status = nil }

        let started = Date()
        let print = fingerprint()
        do {
            let exporter = await Task.detached { JournalExporter(modelContainer: container) }.value
            let zip = try await exporter.export(.json, from: nil, to: nil)
            defer { try? FileManager.default.removeItem(at: zip.deletingLastPathComponent()) }

            status = "Uploading to Google Drive…"
            try await GoogleDrive.upload(fileAt: zip, name: "journi Diary Backup \(Self.nameStamp.string(from: .now)).zip")

            lastFingerprint = print
            lastBackup = .now
            UserDefaults.standard.set(lastBackup, forKey: "googleLastBackup")
            AppLog.info("Google Drive backup done (\(automatic ? "auto" : "manual")) in \(Int(Date().timeIntervalSince(started)))s")

            await trimOldBackups()
        } catch {
            AppLog.error("Google Drive backup failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    private static let nameStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HHmm"
        return f
    }()

    private func trimOldBackups() async {
        guard let files = try? await GoogleDrive.listBackups(), files.count > Self.keepCount else { return }
        for file in files.dropFirst(Self.keepCount) {
            try? await GoogleDrive.delete(file)
        }
    }

    // MARK: Restore

    /// Adds entries from a backup. Entries already in the journal are skipped.
    func restore(_ file: GoogleDrive.File, progress: @escaping @Sendable (Double) -> Void) async throws -> ImportResult {
        guard let container else { throw CancellationError() }
        isWorking = true
        status = "Downloading backup…"
        defer { isWorking = false; status = nil }

        let local = try await GoogleDrive.download(file)
        defer { try? FileManager.default.removeItem(at: local) }
        status = "Restoring entries…"
        let importer = await Task.detached { DayOneImporter(modelContainer: container) }.value
        let result = try await importer.importZip(at: local, progress: progress)
        AppLog.info("Restore done: \(result.imported) added, \(result.skippedDuplicates) skipped")
        return result
    }
}
