import Foundation
import SwiftData
import UIKit
import AVFoundation
import ZIPFoundation

/// Day One JSON export format (only the fields we use).
struct DayOneExport: Decodable {
    struct Entry: Decodable {
        var uuid: String?
        var creationDate: String?
        var text: String?
        var location: Location?
        var photos: [Media]?
        var videos: [Media]?
    }
    struct Location: Decodable {
        var placeName: String?
        var localityName: String?
        var latitude: Double?
        var longitude: Double?
    }
    struct Media: Decodable {
        var identifier: String?
        var md5: String?
        var type: String?
        var orderInEntry: Int?
    }
    var entries: [Entry]
}

struct ImportResult: Sendable {
    var imported = 0
    var skippedDuplicates = 0
    var photosAdded = 0
    var videosAdded = 0
    var mediaOverLimit = 0
    var mediaMissing = 0
}

enum ImportError: LocalizedError {
    case notAZip
    case noJournalFile

    var errorDescription: String? {
        switch self {
        case .notAZip: "This file isn't a .zip archive."
        case .noJournalFile: "No journal .json file was found in the zip."
        }
    }
}

/// Imports a Day One JSON .zip in the background.
/// Works with exports from Day One and with this app's own JSON export.
@ModelActor
actor DayOneImporter {
    func importZip(at zipURL: URL, progress: @Sendable @escaping (Double) -> Void) throws -> ImportResult {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString)")
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        let archive: Archive
        do { archive = try Archive(url: zipURL, accessMode: .read) } catch { throw ImportError.notAZip }

        // Index media files by name (without folder), e.g. "abc123.jpeg".
        var mediaEntries: [String: ZIPFoundation.Entry] = [:]
        var jsonEntries: [ZIPFoundation.Entry] = []
        for entry in archive where entry.type == .file {
            let path = entry.path
            let name = (path as NSString).lastPathComponent
            if name.hasPrefix(".") || path.contains("__MACOSX") { continue }
            if name.lowercased().hasSuffix(".json") {
                jsonEntries.append(entry)
            } else {
                mediaEntries[name.lowercased()] = entry
            }
        }
        guard !jsonEntries.isEmpty else { throw ImportError.noJournalFile }

        var allEntries: [DayOneExport.Entry] = []
        for json in jsonEntries {
            var data = Data()
            _ = try archive.extract(json) { data.append($0) }
            if let export = try? JSONDecoder().decode(DayOneExport.self, from: data) {
                allEntries += export.entries
            }
        }

        // Skip entries imported before.
        let existing = try modelContext.fetch(FetchDescriptor<JournalEntry>())
        let knownIDs = Set(existing.compactMap(\.importID))

        var result = ImportResult()
        for (index, source) in allEntries.enumerated() {
            autoreleasepool {
                if let id = source.uuid, knownIDs.contains(id) {
                    result.skippedDuplicates += 1
                    return
                }
                let entry = makeEntry(from: source)
                modelContext.insert(entry)

                var order = 0
                let photos = (source.photos ?? []).sorted { ($0.orderInEntry ?? 0) < ($1.orderInEntry ?? 0) }
                for (i, photo) in photos.enumerated() {
                    if i >= JournalEntry.maxPhotos { result.mediaOverLimit += 1; continue }
                    guard let file = mediaFile(photo, in: mediaEntries),
                          let raw = extractData(file, from: archive),
                          let image = UIImage(data: raw) else { result.mediaMissing += 1; continue }
                    let full = image.resized(maxSide: 2048).jpegData(compressionQuality: 0.85) ?? raw
                    let thumb = image.resized(maxSide: 300).jpegData(compressionQuality: 0.7)
                    let item = MediaItem(kind: .photo, data: full, thumbnail: thumb, order: order)
                    modelContext.insert(item)
                    item.entry = entry
                    order += 1
                    result.photosAdded += 1
                }

                for (i, video) in (source.videos ?? []).enumerated() {
                    if i >= JournalEntry.maxVideos { result.mediaOverLimit += 1; continue }
                    guard let file = mediaFile(video, in: mediaEntries) else { result.mediaMissing += 1; continue }
                    let url = workDir.appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension((file.path as NSString).pathExtension)
                    guard (try? archive.extract(file, to: url)) != nil,
                          let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                        result.mediaMissing += 1; continue
                    }
                    let thumb = Self.videoThumbnail(url: url)
                    let item = MediaItem(kind: .video, data: data, thumbnail: thumb, order: order)
                    modelContext.insert(item)
                    item.entry = entry
                    try? FileManager.default.removeItem(at: url)
                    order += 1
                    result.videosAdded += 1
                }
                result.imported += 1
            }

            // Save in small batches to keep memory low.
            if index % 20 == 19 { try? modelContext.save() }
            progress(Double(index + 1) / Double(max(allEntries.count, 1)))
        }
        try modelContext.save()
        return result
    }

    private func makeEntry(from source: DayOneExport.Entry) -> JournalEntry {
        let date = source.creationDate.flatMap(Self.parseDate) ?? .now
        let (title, body) = Self.splitText(source.text ?? "")
        let entry = JournalEntry(title: title, body: body, date: date)
        entry.importID = source.uuid
        if let loc = source.location {
            let name = [loc.placeName, loc.localityName].compactMap { $0 }
                .filter { !$0.isEmpty }
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                .joined(separator: ", ")
            entry.placeName = name.isEmpty ? nil : name
            entry.latitude = loc.latitude
            entry.longitude = loc.longitude
        }
        return entry
    }

    private func mediaFile(_ media: DayOneExport.Media,
                           in files: [String: ZIPFoundation.Entry]) -> ZIPFoundation.Entry? {
        for key in [media.md5, media.identifier].compactMap({ $0?.lowercased() }) {
            if let type = media.type?.lowercased(), let hit = files["\(key).\(type)"] { return hit }
            // Fall back to any file whose name starts with the key.
            if let hit = files.first(where: { $0.key.hasPrefix(key + ".") })?.value { return hit }
        }
        return nil
    }

    private func extractData(_ entry: ZIPFoundation.Entry, from archive: Archive) -> Data? {
        var data = Data()
        guard (try? archive.extract(entry, consumer: { data.append($0) })) != nil else { return nil }
        return data
    }

    // MARK: - Helpers

    static func parseDate(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: string)
    }

    /// Day One text is Markdown. Removes image placeholders and escapes,
    /// and uses a leading "# Heading" line (or the first line) as the title.
    static func splitText(_ markdown: String) -> (title: String, body: String) {
        var lines = markdown.components(separatedBy: "\n").filter {
            !$0.contains("dayone-moment://")
        }
        let unescape: (String) -> String = { line in
            line.replacingOccurrences(of: #"\\([\\`*_{}\[\]()#+\-.!>|~])"#, with: "$1",
                                      options: .regularExpression)
        }
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }
        guard let first = lines.first else { return ("", "") }
        var title = ""
        if first.hasPrefix("#") {
            title = first.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            lines.removeFirst()
        }
        let body = lines.map(unescape).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (unescape(title), body)
    }

    static func videoThumbnail(url: URL) -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)
        guard let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.7)
    }
}
