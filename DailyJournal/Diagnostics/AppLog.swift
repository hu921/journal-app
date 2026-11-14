import Foundation
import os
import MetricKit
import UIKit

/// Simple on-device log for finding bugs and slow spots.
/// Writes app events (never journal text) to Library/Logs/DailyLog, keeps
/// crash reports from Apple (MetricKit), and records fatal signals.
/// Settings > About > Share Logs bundles it all into one text file.
enum AppLog {
    private static let logger = Logger(subsystem: "com.sarahu.dailyjournal", category: "app")
    private static let queue = DispatchQueue(label: "AppLog")
    private static let maxBytes = 1_000_000

    static let folder: URL = {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/DailyLog", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    private static var logFile: URL { folder.appendingPathComponent("app.log") }
    private static var oldLogFile: URL { folder.appendingPathComponent("app.old.log") }
    static var crashFile: URL { folder.appendingPathComponent("crash.log") }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    // MARK: Writing

    static func info(_ message: String, file: String = #fileID, line: Int = #line) {
        write("INFO", message, file: file, line: line)
    }

    static func error(_ message: String, file: String = #fileID, line: Int = #line) {
        write("ERROR", message, file: file, line: line)
    }

    /// Logs how long a block took if it was slower than `slowerThan` seconds.
    @discardableResult
    static func measure<T>(_ name: String, slowerThan: Double = 0.1, _ work: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let seconds = CFAbsoluteTimeGetCurrent() - start
            if seconds >= slowerThan { write("SLOW", "\(name) took \(Int(seconds * 1000)) ms", file: "", line: 0) }
        }
        return try work()
    }

    private static func write(_ level: String, _ message: String, file: String, line: Int) {
        let now = Date()
        let thread = Thread.isMainThread ? "main" : "bg"
        let place = file.isEmpty ? "" : " \((file as NSString).lastPathComponent):\(line)"
        logger.log("\(level, privacy: .public) \(message, privacy: .public)")
        queue.async {
            let text = "\(stamp.string(from: now)) [\(level)] [\(thread)]\(place) \(message)\n"
            append(text)
        }
    }

    private static func append(_ text: String) {
        let fm = FileManager.default
        if let size = (try? fm.attributesOfItem(atPath: logFile.path))?[.size] as? Int, size > maxBytes {
            try? fm.removeItem(at: oldLogFile)
            try? fm.moveItem(at: logFile, to: oldLogFile)
        }
        if !fm.fileExists(atPath: logFile.path) { fm.createFile(atPath: logFile.path, contents: nil) }
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
            try? handle.close()
        }
    }

    // MARK: Startup

    static func start() {
        CrashCatcher.install(crashFile: crashFile)
        MXMetricManager.shared.add(MetricReceiver.shared)
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?"))"
        AppLog.info("App launch. Version \(version), iOS \(UIDevice.current.systemVersion), \(deviceModel()), memory \(memoryMB()) MB")
        let crashSize = (try? FileManager.default.attributesOfItem(atPath: crashFile.path))?[.size] as? Int ?? 0
        if crashSize > 0 {
            AppLog.error("Previous run crashed. See crash.log in the shared logs.")
        }
    }

    /// Memory the app is using now, in MB.
    static func memoryMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : -1
    }

    static func deviceModel() -> String {
        var sys = utsname()
        uname(&sys)
        return withUnsafeBytes(of: &sys.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    // MARK: Sharing

    /// Joins all log files into one text file to share.
    static func exportFile() -> URL? {
        let fm = FileManager.default
        var parts: [String] = ["Daily Log diagnostics, exported \(stamp.string(from: .now))",
                               "Device \(deviceModel()), iOS \(UIDevice.current.systemVersion), memory now \(memoryMB()) MB", ""]
        let files = ((try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            parts.append("===== \(file.lastPathComponent) =====")
            parts.append(text)
        }
        let out = fm.temporaryDirectory.appendingPathComponent("DailyLog-logs-\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try parts.joined(separator: "\n").write(to: out, atomically: true, encoding: .utf8)
            return out
        } catch {
            return nil
        }
    }

    static func clear() {
        let fm = FileManager.default
        for file in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: file)
        }
        info("Logs cleared")
    }
}

/// Receives Apple's crash, hang and performance reports (delivered on a later launch).
final class MetricReceiver: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricReceiver()

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for (i, payload) in payloads.enumerated() {
            let name = "diagnostic-\(Int(Date().timeIntervalSince1970))-\(i).json"
            try? payload.jsonRepresentation().write(to: AppLog.folder.appendingPathComponent(name))
            AppLog.info("Saved Apple diagnostic report \(name): crashes \(payload.crashDiagnostics?.count ?? 0), hangs \(payload.hangDiagnostics?.count ?? 0)")
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for (i, payload) in payloads.enumerated() {
            let name = "metrics-\(Int(Date().timeIntervalSince1970))-\(i).json"
            try? payload.jsonRepresentation().write(to: AppLog.folder.appendingPathComponent(name))
        }
        AppLog.info("Saved \(payloads.count) Apple metric report(s)")
    }
}
