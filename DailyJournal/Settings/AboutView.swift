import SwiftUI

struct AboutView: View {
    @State private var logURL: URL?
    @State private var confirmClear = false
    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                    Text("Daily Log: Journal").appFont(.title2, weight: .bold)
                    Text("Version \(version)").appFont(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                Text("A simple journal for your days. Write entries, add photos and videos, and keep them in sync with iCloud.")
            }

            Section("Data") {
                Label("Entries are saved on your device and synced with your iCloud account.", systemImage: "icloud")
            }

            Section {
                Button {
                    logURL = AppLog.exportFile()
                } label: {
                    Label("Share Logs", systemImage: "doc.text.magnifyingglass")
                }
                Button(role: .destructive) {
                    confirmClear = true
                } label: {
                    Label("Clear Logs", systemImage: "trash")
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Logs record app events, timings and crashes to help fix problems. They never include your journal text or photos.")
            }

            Section("Credits") {
                Text("Roboto, Lato and Open Sans are used under the SIL Open Font License 1.1.")
                    .appFont(.footnote)
                Text("Day One is a trademark of its owner. Daily Log is an independent app and is not affiliated with or endorsed by Day One.")
                    .appFont(.footnote)
            }
        }
        .sheet(item: $logURL) { url in
            ShareSheet(items: [url])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Clear all logs?", isPresented: $confirmClear) {
            Button("Clear Logs", role: .destructive) { AppLog.clear() }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
