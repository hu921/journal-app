import Foundation
import Darwin

/// Writes a stack trace to crash.log when the app crashes, so it can be shared
/// on the next launch. Uses only low-level calls that are safe inside a crash.
enum CrashCatcher {
    private static var fd: Int32 = -1
    private static let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGFPE]

    static func install(crashFile: URL) {
        // Open the file now; opening it during a crash isn't safe.
        fd = open(crashFile.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)

        NSSetUncaughtExceptionHandler { exception in
            let text = "\n=== Uncaught exception \(Date()) ===\n\(exception.name.rawValue): \(exception.reason ?? "")\n"
                + exception.callStackSymbols.joined(separator: "\n") + "\n"
            CrashCatcher.writeRaw(text)
        }

        for sig in signals {
            signal(sig) { number in
                CrashCatcher.writeRaw("\n=== Crash signal \(number) ===\n")
                var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 64)
                let count = backtrace(&frames, Int32(frames.count))
                backtrace_symbols_fd(&frames, count, CrashCatcher.fd)
                // Let the system crash normally so Apple's report is made too.
                signal(number, SIG_DFL)
                raise(number)
            }
        }
    }

    fileprivate static func writeRaw(_ text: String) {
        guard fd >= 0 else { return }
        text.utf8CString.withUnsafeBufferPointer { buf in
            _ = write(fd, buf.baseAddress, max(buf.count - 1, 0))
        }
    }
}
