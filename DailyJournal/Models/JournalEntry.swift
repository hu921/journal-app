import Foundation
import SwiftData

/// One journal entry. A day can have many entries.
/// CloudKit sync rules: every property needs a default or must be optional,
/// relationships must be optional, and no unique constraints.
@Model
final class JournalEntry {
    var title: String = ""
    var body: String = ""
    var date: Date = Date()
    var placeName: String?
    var latitude: Double?
    var longitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \MediaItem.entry)
    var media: [MediaItem]? = []

    init(title: String = "", body: String = "", date: Date = .now) {
        self.title = title
        self.body = body
        self.date = date
    }

    static let maxPhotos = 5
    static let maxVideos = 2

    var sortedMedia: [MediaItem] {
        (media ?? []).sorted { $0.order < $1.order }
    }
    var photos: [MediaItem] { sortedMedia.filter { $0.kind == .photo } }
    var videos: [MediaItem] { sortedMedia.filter { $0.kind == .video } }

    /// First image to show as the list thumbnail.
    var thumbnailData: Data? { sortedMedia.first?.thumbnail }

    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Untitled" : firstLine
    }
}
