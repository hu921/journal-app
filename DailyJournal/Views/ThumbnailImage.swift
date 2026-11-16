import SwiftUI
import SwiftData
import ImageIO

/// Decodes thumbnails off the main thread and keeps them in memory,
/// so scrolling the list, calendar and map doesn't stutter.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        // Limit by memory, not count: 600 decoded thumbnails could use 200 MB.
        cache.totalCostLimit = 40 * 1024 * 1024
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil, queue: nil) { [cache] _ in cache.removeAllObjects() }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: nil) { [cache] _ in cache.removeAllObjects() }
    }

    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func store(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    static func decode(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            // Decode at thumbnail size only, so a large stored image never decodes in full.
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: 300,
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }.value
    }
}

/// Shows an entry's first thumbnail, loading it in the background.
/// It reads only the small thumbnail column, so full photos and videos are never loaded
/// just to draw a list row (that used hundreds of MB and drained battery).
struct EntryThumbnail: View {
    let entry: JournalEntry
    @Environment(\.modelContext) private var context
    @State private var image: UIImage?

    var body: some View {
        // Changes when media is added or removed. Doesn't touch the media rows themselves.
        let key = "\(entry.persistentModelID.hashValue)-\(entry.media?.count ?? 0)"
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
            guard entry.hasMedia else { image = nil; return }
            let data = await Self.firstThumbnail(of: entry.persistentModelID, container: context.container)
            guard let data, !Task.isCancelled else { return }
            if let decoded = await ThumbnailCache.decode(data) {
                ThumbnailCache.shared.store(decoded, for: key)
                image = decoded
            }
        }
    }

    /// Fetches only `thumbnail` and `order` of the entry's first media item, on a background context.
    static func firstThumbnail(of entryID: PersistentIdentifier, container: ModelContainer) async -> Data? {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<MediaItem>(
                predicate: #Predicate { $0.entry?.persistentModelID == entryID },
                sortBy: [SortDescriptor(\.order)]
            )
            descriptor.fetchLimit = 1
            descriptor.propertiesToFetch = [\.thumbnail, \.order]
            do {
                return try context.fetch(descriptor).first?.thumbnail
            } catch {
                // Fallback: go through the entry (loads more, but always works).
                AppLog.info("Thumbnail fetch fallback: \(error.localizedDescription)")
                let entry = context.model(for: entryID) as? JournalEntry
                return entry?.thumbnailData
            }
        }.value
    }
}
