import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// Movie file handed over by PhotosPicker.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}

enum MediaLoader {
    struct Loaded {
        let kind: MediaKind
        let data: Data
        let thumbnail: Data?
    }

    static func load(_ item: PhotosPickerItem) async -> Loaded? {
        let isMovie = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isMovie {
            guard let movie = try? await item.loadTransferable(type: PickedMovie.self),
                  let data = try? Data(contentsOf: movie.url) else { return nil }
            let thumb = await videoThumbnail(url: movie.url)
            try? FileManager.default.removeItem(at: movie.url)
            return Loaded(kind: .video, data: data, thumbnail: thumb)
        } else {
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw) else { return nil }
            // Store a reasonably sized JPEG to keep iCloud usage low.
            let full = image.resized(maxSide: 2048).jpegData(compressionQuality: 0.85) ?? raw
            let thumb = image.resized(maxSide: 300).jpegData(compressionQuality: 0.7)
            return Loaded(kind: .photo, data: full, thumbnail: thumb)
        }
    }

    static func videoThumbnail(url: URL) async -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)
        guard let (cg, _) = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.7)
    }

    /// Writes video data to a temp file so AVPlayer can play it.
    static func tempURL(forVideo data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        do { try data.write(to: url); return url } catch { return nil }
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
