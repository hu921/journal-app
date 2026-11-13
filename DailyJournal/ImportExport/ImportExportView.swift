import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export entries in several formats, or import a Day One JSON .zip.
struct ImportExportView: View {
    @Environment(\.modelContext) private var context

    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var counts: (entries: Int, media: Int)?

    @State private var working: String?
    @State private var progress: Double?
    @State private var shareURL: URL?
    @State private var showImporter = false
    @State private var alert: AlertInfo?

    private var range: (Date?, Date?) { useDateRange ? (startDate, endDate) : (nil, nil) }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                    Text("Your entries are always yours. Export a copy any time, or bring entries in from Day One.")
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Only a date range", isOn: $useDateRange)
                if useDateRange {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            } header: {
                Text("Export")
            } footer: {
                if let counts {
                    Text("\(counts.entries) entries, \(counts.media) photos and videos")
                }
            }

            Section {
                ForEach(ExportFormat.allCases) { format in
                    Button(format.label) { export(format) }
                        .disabled(working != nil || counts?.entries == 0)
                }
            }

            Section {
                Button("Import Day One JSON (.zip)") { showImporter = true }
                    .disabled(working != nil)
            } header: {
                Text("Import")
            } footer: {
                Text("In Day One: Settings > Import/Export > Export Day One JSON. Entries already imported are skipped. Up to \(JournalEntry.maxPhotos) photos and \(JournalEntry.maxVideos) videos are kept per entry.")
            }
        }
        .navigationTitle("Import / Export")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(useDateRange)\(startDate)\(endDate)") { await refreshCounts() }
        .overlay { if let working { WorkingOverlay(title: working, progress: progress) } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.zip]) { result in
            if case .success(let url) = result { importDayOne(url) }
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url])
                .presentationDetents([.medium, .large])
        }
        .alert(item: $alert) { info in
            Alert(title: Text(info.title), message: Text(info.message))
        }
    }

    private func refreshCounts() async {
        let exporter = JournalExporter(modelContainer: context.container)
        let (s, e) = range
        counts = try? await exporter.count(from: s, to: e)
    }

    private func export(_ format: ExportFormat) {
        working = "Preparing export…"
        progress = nil
        let container = context.container
        let (s, e) = range
        Task {
            do {
                try? context.save()
                // Create the actor off the main thread so the work runs in the background.
                let exporter = await Task.detached { JournalExporter(modelContainer: container) }.value
                let url = try await exporter.export(format, from: s, to: e)
                working = nil
                shareURL = url
            } catch {
                working = nil
                alert = AlertInfo(title: "Export failed", message: error.localizedDescription)
            }
        }
    }

    private func importDayOne(_ url: URL) {
        working = "Importing…"
        progress = 0
        let container = context.container
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                // Copy out of Files first; reading in place can be slow or blocked.
                let local = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString).appendingPathExtension("zip")
                try FileManager.default.copyItem(at: url, to: local)
                defer { try? FileManager.default.removeItem(at: local) }

                let importer = await Task.detached { DayOneImporter(modelContainer: container) }.value
                let result = try await importer.importZip(at: local) { value in
                    Task { @MainActor in progress = value }
                }
                working = nil
                alert = AlertInfo(title: "Import finished", message: Self.summary(result))
                await refreshCounts()
            } catch {
                working = nil
                alert = AlertInfo(title: "Import failed", message: error.localizedDescription)
            }
        }
    }

    private static func summary(_ r: ImportResult) -> String {
        var lines = ["\(r.imported) entries imported", "\(r.photosAdded) photos, \(r.videosAdded) videos"]
        if r.skippedDuplicates > 0 { lines.append("\(r.skippedDuplicates) already imported, skipped") }
        if r.mediaOverLimit > 0 { lines.append("\(r.mediaOverLimit) photos or videos over the per-entry limit, skipped") }
        if r.mediaMissing > 0 { lines.append("\(r.mediaMissing) photos or videos missing from the zip") }
        return lines.joined(separator: "\n")
    }
}

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct WorkingOverlay: View {
    let title: String
    let progress: Double?

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                if let progress {
                    ProgressView(value: progress)
                        .frame(width: 180)
                    Text("\(title) \(Int(progress * 100))%")
                } else {
                    ProgressView()
                    Text(title)
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// iOS share sheet: Save to Files, AirDrop, Mail, Google Drive app, etc.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
