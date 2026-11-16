import Foundation

/// The few Google Drive calls the backup needs. Backups go in a "Daily Log Backups" folder.
/// With the drive.file scope, the app only sees files it created itself.
struct GoogleDrive {
    struct File: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let createdTime: Date?
        let size: String?

        var bytes: Int64 { Int64(size ?? "") ?? 0 }
    }

    enum DriveError: LocalizedError {
        case http(Int, String)
        var errorDescription: String? {
            switch self {
            case .http(let code, let body): "Google Drive error \(code): \(body.prefix(200))"
            }
        }
    }

    static let folderName = "Daily Log Backups"
    private static let api = "https://www.googleapis.com/drive/v3"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? .distantPast
        }
        return d
    }()

    // MARK: Requests

    private static func request(_ url: URL, method: String = "GET") async throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(try await GoogleAuth.shared.validAccessToken())", forHTTPHeaderField: "Authorization")
        return req
    }

    @discardableResult
    private static func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: req)
        let http = response as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else {
            throw DriveError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return (data, http)
    }

    private static func url(_ path: String, _ query: [String: String]) -> URL {
        var c = URLComponents(string: api + path)!
        c.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return c.url!
    }

    // MARK: Folder

    /// Finds the backup folder, or creates it.
    static func folderID() async throws -> String {
        let q = "name = '\(folderName)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        let req = try await request(url("/files", ["q": q, "fields": "files(id)", "spaces": "drive"]))
        let (data, _) = try await send(req)
        struct List: Decodable { struct F: Decodable { let id: String }; let files: [F] }
        if let id = try JSONDecoder().decode(List.self, from: data).files.first?.id { return id }

        var create = try await request(url("/files", ["fields": "id"]), method: "POST")
        create.setValue("application/json", forHTTPHeaderField: "Content-Type")
        create.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": folderName, "mimeType": "application/vnd.google-apps.folder",
        ])
        let (created, _) = try await send(create)
        struct Made: Decodable { let id: String }
        return try JSONDecoder().decode(Made.self, from: created).id
    }

    // MARK: Files

    /// Backups in the folder, newest first.
    static func listBackups() async throws -> [File] {
        let folder = try await folderID()
        let req = try await request(url("/files", [
            "q": "'\(folder)' in parents and trashed = false",
            "orderBy": "createdTime desc",
            "fields": "files(id,name,createdTime,size)",
            "pageSize": "50",
        ]))
        let (data, _) = try await send(req)
        struct List: Decodable { let files: [File] }
        return try decoder.decode(List.self, from: data).files
    }

    /// Uploads a file with a resumable upload, so large backups with videos work.
    static func upload(fileAt local: URL, name: String) async throws {
        let folder = try await folderID()
        let size = (try? FileManager.default.attributesOfItem(atPath: local.path)[.size] as? Int) ?? 0

        var start = try await request(
            URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable")!, method: "POST")
        start.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        start.setValue("application/zip", forHTTPHeaderField: "X-Upload-Content-Type")
        start.setValue(String(size), forHTTPHeaderField: "X-Upload-Content-Length")
        start.httpBody = try JSONSerialization.data(withJSONObject: ["name": name, "parents": [folder]])
        let (_, response) = try await send(start)
        guard let location = response.value(forHTTPHeaderField: "Location"), let uploadURL = URL(string: location) else {
            throw DriveError.http(0, "No upload address returned")
        }

        var put = URLRequest(url: uploadURL)
        put.httpMethod = "PUT"
        put.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        let (data, putResponse) = try await URLSession.shared.upload(for: put, fromFile: local)
        let code = (putResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DriveError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Downloads a backup to a temporary file.
    static func download(_ file: File) async throws -> URL {
        let req = try await request(url("/files/\(file.id)", ["alt": "media"]))
        let (temp, response) = try await URLSession.shared.download(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw DriveError.http(code, "Download failed") }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString).zip")
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
    }

    static func delete(_ file: File) async throws {
        try await send(try await request(url("/files/\(file.id)", [:]), method: "DELETE"))
    }
}
