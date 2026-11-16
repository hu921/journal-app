import Foundation

/// Where exports are saved so people can find them in the Files app.
/// On My iPhone > journi Diary > journi Diary Backups
/// iCloud Drive > journi Diary > journi Diary Backups
enum BackupFolders {
    static let folderName = "journi Diary Backups"
    static let iCloudContainer = "iCloud.com.sarahu.dailyjournal"

    enum Place: String, CaseIterable, Identifiable {
        case onMyiPhone, iCloudDrive, share
        var id: String { rawValue }
        var label: String {
            switch self {
            case .onMyiPhone: "On My iPhone"
            case .iCloudDrive: "iCloud Drive"
            case .share: "Share…"
            }
        }
        var path: String {
            switch self {
            case .onMyiPhone: "Files > On My iPhone > journi Diary > \(BackupFolders.folderName)"
            case .iCloudDrive: "Files > iCloud Drive > journi Diary > \(BackupFolders.folderName)"
            case .share: ""
            }
        }
    }

    enum FolderError: LocalizedError {
        case iCloudUnavailable
        var errorDescription: String? {
            "iCloud Drive is off. Turn it on in Settings > your name > iCloud > iCloud Drive."
        }
    }

    /// The folder for a place, created if needed. Call off the main thread:
    /// finding the iCloud container can take a moment.
    static func folder(for place: Place) throws -> URL {
        let fm = FileManager.default
        let base: URL
        switch place {
        case .onMyiPhone, .share:
            base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .iCloudDrive:
            guard let container = fm.url(forUbiquityContainerIdentifier: iCloudContainer) else {
                throw FolderError.iCloudUnavailable
            }
            base = container.appendingPathComponent("Documents", isDirectory: true)
        }
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copies a finished export into the folder for a place. Returns the saved file.
    static func save(_ file: URL, to place: Place) throws -> URL {
        let dest = try folder(for: place).appendingPathComponent(file.lastPathComponent)
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        if place == .iCloudDrive {
            // Let iOS move it into iCloud Drive and upload it.
            let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + file.lastPathComponent)
            try fm.copyItem(at: file, to: temp)
            try fm.setUbiquitous(true, itemAt: temp, destinationURL: dest)
        } else {
            try fm.copyItem(at: file, to: dest)
        }
        return dest
    }
}
