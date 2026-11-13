import Foundation
import SwiftData
import UIKit
import CryptoKit
import ZIPFoundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case json, plainText, csv, pdf
    var id: String { rawValue }

    var label: String {
        switch self {
        case .json: "Export JSON (.zip)"
        case .plainText: "Export Plain Text (.zip)"
        case .csv: "Export Comma Separated (.csv)"
        case .pdf: "Export PDF"
        }
    }
}

/// Builds export files in the background. Returns a file URL to share.
@ModelActor
actor JournalExporter {
    func export(_ format: ExportFormat, from start: Date?, to end: Date?) throws -> URL {
        let entries = try fetch(from: start, to: end)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = Self.fileStamp.string(from: .now)

        switch format {
        case .json: return try exportJSON(entries, in: dir, name: "Daily Log \(stamp)")
        case .plainText: return try exportText(entries, in: dir, name: "Daily Log \(stamp)")
        case .csv: return try exportCSV(entries, in: dir, name: "Daily Log \(stamp)")
        case .pdf: return try PDFExporter.render(entries, to: dir.appendingPathComponent("Daily Log \(stamp).pdf"))
        }
    }

    func count(from start: Date?, to end: Date?) throws -> (entries: Int, media: Int) {
        let entries = try fetch(from: start, to: end)
        return (entries.count, entries.reduce(0) { $0 + ($1.media?.count ?? 0) })
    }

    private func fetch(from start: Date?, to end: Date?) throws -> [JournalEntry] {
        let lower = start.map { Calendar.current.startOfDay(for: $0) } ?? .distantPast
        let upper = end.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0)) }
            ?? .distantFuture
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.date >= lower && $0.date < upper },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: JSON (.zip), compatible with Day One's JSON layout

    private struct JSONExport: Encodable {
        struct Entry: Encodable {
            var uuid: String
            var creationDate: String
            var text: String
            var location: Location?
            var photos: [Media]?
            var videos: [Media]?
        }
        struct Location: Encodable {
            var placeName: String?
            var latitude: Double?
            var longitude: Double?
        }
        struct Media: Encodable {
            var identifier: String
            var md5: String
            var type: String
            var orderInEntry: Int
        }
        var metadata = ["version": "1.0", "app": "Daily Log: Journal"]
        var entries: [Entry]
    }

    private func exportJSON(_ entries: [JournalEntry], in dir: URL, name: String) throws -> URL {
        let folder = dir.appendingPathComponent(name)
        let photosDir = folder.appendingPathComponent("photos")
        let videosDir = folder.appendingPathComponent("videos")
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)

        let iso = ISO8601DateFormatter()
        var out: [JSONExport.Entry] = []
        for entry in entries {
            try autoreleasepool {
                var photos: [JSONExport.Media] = []
                var videos: [JSONExport.Media] = []
                for (i, item) in entry.sortedMedia.enumerated() {
                    guard let data = item.data else { continue }
                    let md5 = Self.md5(data)
                    let type = item.kind == .photo ? "jpeg" : "mov"
                    let target = (item.kind == .photo ? photosDir : videosDir)
                        .appendingPathComponent("\(md5).\(type)")
                    try data.write(to: target)
                    let media = JSONExport.Media(identifier: md5.uppercased(), md5: md5, type: type, orderInEntry: i)
                    if item.kind == .photo { photos.append(media) } else { videos.append(media) }
                }
                let text = entry.title.isEmpty ? entry.body : "# \(entry.title)\n\n\(entry.body)"
                let location = entry.placeName == nil && entry.latitude == nil ? nil :
                    JSONExport.Location(placeName: entry.placeName, latitude: entry.latitude, longitude: entry.longitude)
                out.append(.init(
                    uuid: entry.importID ?? Self.stableID(for: entry),
                    creationDate: iso.string(from: entry.date),
                    text: text,
                    location: location,
                    photos: photos.isEmpty ? nil : photos,
                    videos: videos.isEmpty ? nil : videos))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(JSONExport(entries: out)).write(to: folder.appendingPathComponent("Journal.json"))
        return try zip(folder)
    }

    // MARK: Plain text (.zip)

    private func exportText(_ entries: [JournalEntry], in dir: URL, name: String) throws -> URL {
        let folder = dir.appendingPathComponent(name)
        let mediaDir = folder.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .short
        let fileDF = DateFormatter()
        fileDF.dateFormat = "yyyy-MM-dd_HHmm"

        var text = ""
        for entry in entries {
            try autoreleasepool {
                text += "Date: \(df.string(from: entry.date))\n"
                if let place = entry.placeName { text += "Location: \(place)\n" }
                var files: [String] = []
                for (i, item) in entry.sortedMedia.enumerated() {
                    guard let data = item.data else { continue }
                    let file = "\(fileDF.string(from: entry.date))_\(i + 1).\(item.kind == .photo ? "jpg" : "mov")"
                    try data.write(to: mediaDir.appendingPathComponent(file))
                    files.append(file)
                }
                if !files.isEmpty { text += "Media: \(files.joined(separator: ", "))\n" }
                text += "\n"
                if !entry.title.isEmpty { text += "\(entry.title)\n\n" }
                text += "\(entry.body)\n\n----------\n\n"
            }
        }
        try text.write(to: folder.appendingPathComponent("Journal.txt"), atomically: true, encoding: .utf8)
        return try zip(folder)
    }

    // MARK: CSV

    private func exportCSV(_ entries: [JournalEntry], in dir: URL, name: String) throws -> URL {
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        var rows = ["date,title,text,location,latitude,longitude,photos,videos"]
        for e in entries {
            rows.append([
                iso.string(from: e.date),
                e.title,
                e.body,
                e.placeName ?? "",
                e.latitude.map { String($0) } ?? "",
                e.longitude.map { String($0) } ?? "",
                String(e.photos.count),
                String(e.videos.count),
            ].map(Self.csvField).joined(separator: ","))
        }
        let url = dir.appendingPathComponent("\(name).csv")
        // BOM so Excel opens UTF-8 (Chinese text etc.) correctly.
        try ("\u{FEFF}" + rows.joined(separator: "\r\n")).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Helpers

    private func zip(_ folder: URL) throws -> URL {
        let zipURL = folder.deletingLastPathComponent().appendingPathComponent(folder.lastPathComponent + ".zip")
        try FileManager.default.zipItem(at: folder, to: zipURL, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: folder)
        return zipURL
    }

    static func csvField(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func md5(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Same entry gets the same ID on every export, so re-importing skips it.
    static func stableID(for entry: JournalEntry) -> String {
        let key = "\(entry.date.timeIntervalSince1970)|\(entry.title)|\(entry.body)"
        return md5(Data(key.utf8)).uppercased()
    }

    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
