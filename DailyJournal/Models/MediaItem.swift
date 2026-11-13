import Foundation
import SwiftData

enum MediaKind: String, Codable {
    case photo, video
}

/// A photo or video attached to an entry.
/// Large data uses external storage, which CloudKit syncs as an asset.
@Model
final class MediaItem {
    var kindRaw: String = MediaKind.photo.rawValue
    var order: Int = 0
    var createdAt: Date = Date()

    @Attribute(.externalStorage) var data: Data?
    /// Small JPEG used in the list and grid. For videos, a frame grab.
    @Attribute(.externalStorage) var thumbnail: Data?

    var entry: JournalEntry?

    var kind: MediaKind {
        get { MediaKind(rawValue: kindRaw) ?? .photo }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: MediaKind, data: Data, thumbnail: Data?, order: Int) {
        self.kindRaw = kind.rawValue
        self.data = data
        self.thumbnail = thumbnail
        self.order = order
    }
}
