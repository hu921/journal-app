import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import ImageIO
import CoreLocation

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
        /// When and where the photo or video was taken, if it says.
        var takenAt: Date? = nil
        var coordinate: CLLocationCoordinate2D? = nil
    }

    static func load(_ item: PhotosPickerItem) async -> Loaded? {
        let isMovie = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isMovie {
            guard let movie = try? await item.loadTransferable(type: PickedMovie.self),
                  let data = try? Data(contentsOf: movie.url) else { return nil }
            let thumb = await videoThumbnail(url: movie.url)
            let (date, coord) = await videoMetadata(url: movie.url)
            try? FileManager.default.removeItem(at: movie.url)
            return Loaded(kind: .video, data: data, thumbnail: thumb, takenAt: date, coordinate: coord)
        } else {
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw) else { return nil }
            // Read date and GPS before re-encoding, which drops them.
            let (date, coord) = photoMetadata(raw)
            // Store a reasonably sized JPEG to keep iCloud usage low.
            let full = image.resized(maxSide: 2048).jpegData(compressionQuality: 0.85) ?? raw
            let thumb = image.resized(maxSide: 300).jpegData(compressionQuality: 0.7)
            return Loaded(kind: .photo, data: full, thumbnail: thumb, takenAt: date, coordinate: coord)
        }
    }

    /// Date taken and GPS from a photo's EXIF data.
    static func photoMetadata(_ data: Data) -> (Date?, CLLocationCoordinate2D?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (nil, nil)
        }
        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String
            date = parseExifDate(text, offset: offset)
        } else if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                  let text = tiff[kCGImagePropertyTIFFDateTime] as? String {
            date = parseExifDate(text, offset: nil)
        }
        var coord: CLLocationCoordinate2D?
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           var lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           var lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            if (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S" { lat = -lat }
            if (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W" { lon = -lon }
            coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return (date, coord)
    }

    /// EXIF dates look like "2025:10:05 21:21:00", with an optional offset like "+08:00".
    static func parseExifDate(_ text: String, offset: String?) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if let offset {
            f.dateFormat = "yyyy:MM:dd HH:mm:ssXXX"
            if let d = f.date(from: text + offset) { return d }
        }
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.timeZone = .current
        return f.date(from: text)
    }

    /// Creation date and location saved in a video file.
    static func videoMetadata(url: URL) async -> (Date?, CLLocationCoordinate2D?) {
        let asset = AVURLAsset(url: url)
        var date: Date?
        var coord: CLLocationCoordinate2D?
        if let item = try? await asset.load(.creationDate) {
            date = try? await item.load(.dateValue)
        }
        if let metadata = try? await asset.load(.commonMetadata) {
            let locations = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierLocation)
            if let first = locations.first, let text = try? await first.load(.stringValue) {
                coord = parseISO6709(text)
            }
        }
        return (date, coord)
    }

    /// Parses "+22.6273+120.3014+012.345/" style locations.
    static func parseISO6709(_ text: String) -> CLLocationCoordinate2D? {
        let pattern = #"([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let latRange = Range(m.range(at: 1), in: text),
              let lonRange = Range(m.range(at: 2), in: text),
              let lat = Double(text[latRange]), let lon = Double(text[lonRange]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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
