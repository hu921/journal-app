import SwiftUI

struct AboutView: View {
    @State private var logURL: URL?
    @State private var confirmClear = false
    @AppStorage(SettingsKey.appColor) private var appColor = AppColor.orange.rawValue

    /// Support email shown in About. Empty for now; fill in to show a tappable address.
    static let contactEmail = ""
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
                    Image(AppColor.from(appColor).logoName)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityHidden(true)
                    Text("journipod Diary: Journal").appFont(.title2, weight: .bold)
                    Text("Version \(version)").appFont(.subheadline).foregroundStyle(.secondary)
                    Text("© 2026 journipod").appFont(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                Text("A simple journal for your days. Write entries, add photos and videos, and keep them in sync with iCloud.")
            }

            Section("App") {
                LabeledContent("Version", value: version)
                if Self.contactEmail.isEmpty {
                    LabeledContent("Contact", value: "")
                } else if let url = URL(string: "mailto:\(Self.contactEmail)") {
                    LabeledContent("Contact") {
                        Link(Self.contactEmail, destination: url)
                    }
                }
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
