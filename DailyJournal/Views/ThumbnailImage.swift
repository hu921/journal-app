import SwiftUI
import SwiftData

/// Decodes thumbnails off the main thread and keeps them in memory,
/// so scrolling the list, calendar and map doesn't stutter.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.countLimit = 600 }

    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func store(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }

    static func decode(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            UIImage(data: data)?.preparingForDisplay()
        }.value
    }
}

/// Shows an entry's first thumbnail, loading it in the background.
struct EntryThumbnail: View {
    let entry: JournalEntry
    @State private var image: UIImage?

    private var key: String {
        // Changes when the first media item changes.
        let first = entry.sortedMedia.first
        return "\(entry.persistentModelID.hashValue)-\(first.map { "\($0.persistentModelID.hashValue)" } ?? "none")"
    }

    var body: some View {
        let key = key
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: key) {
            if let cached = ThumbnailCache.shared.image(for: key) {
                image = cached
                return
            }
            guard let data = entry.thumbnailData else { image = nil; return }
            if let decoded = await ThumbnailCache.decode(data) {
                ThumbnailCache.shared.store(decoded, for: key)
                image = decoded
            }
        }
    }
}
