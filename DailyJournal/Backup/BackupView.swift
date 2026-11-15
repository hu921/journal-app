import SwiftUI

/// Settings > Backup: iCloud sync (always on) and Google Drive backup and restore.
struct BackupView: View {
    @ObservedObject private var backup = BackupManager.shared
    @ObservedObject private var google = GoogleAuth.shared
    @State private var notSetUp = false

    private var googleToggle: Binding<Bool> {
        Binding(
            get: { backup.isOn },
            set: { on in
                if on && GoogleAuth.clientID == nil {
                    notSetUp = true
                    return
                }
                if on { Task { await backup.turnOn() } } else { backup.turnOff(signOut: false) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("On")
                } label: {
                    Label("iCloud Sync", systemImage: "icloud")
                }
            } footer: {
                Text("Your entries sync to every device signed in to your Apple Account.")
            }

            Section {
                Toggle(isOn: googleToggle) {
                    Label("Back Up to Google Drive", systemImage: "externaldrive")
                }
                .disabled(backup.isWorking)

                if backup.isOn {
                    if let email = google.email {
                        LabeledContent("Account", value: email)
                    }
                    LabeledContent("Last Backup") {
                        if let last = backup.lastBackup {
                            Text(last, format: .relative(presentation: .named))
                        } else {
                            Text("Not yet")
                        }
                    }
                    Button {
                        Task { await backup.backUpNow() }
                    } label: {
                        HStack {
                            Text("Back Up Now")
                            Spacer()
                            if backup.isWorking { ProgressView() }
                        }
                    }
                    .disabled(backup.isWorking)

                    if let status = backup.status {
                        Text(status).appFont(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let error = backup.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .appFont(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Google Drive")
            } footer: {
                if GoogleAuth.clientID == nil {
                    Text("Google Drive backup isn't set up in this build yet.")
                } else {
                    Text("Backs up automatically when you add entries and leave the app. The last \(BackupManager.keepCount) backups are kept in the \"\(GoogleDrive.folderName)\" folder in your Google Drive.")
                }
            }

            if google.isSignedIn {
                Section {
                    NavigationLink {
                        RestoreView()
                    } label: {
                        Label("Restore from Google Drive", systemImage: "arrow.counterclockwise")
                    }
                    Button("Sign Out of Google", role: .destructive) {
                        backup.turnOff(signOut: true)
                    }
                    .disabled(backup.isWorking)
                }
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Google Drive Not Ready", isPresented: $notSetUp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Google sign-in isn't set up in this test build yet. It will work in a later build.")
        }
    }
}

/// Pick a Google Drive backup and add its entries back.
private struct RestoreView: View {
    @ObservedObject private var backup = BackupManager.shared
    @State private var files: [GoogleDrive.File]?
    @State private var loadError: String?
    @State private var chosen: GoogleDrive.File?
    @State private var progress: Double?
    @State private var alert: AlertInfo?

    var body: some View {
        List {
            if let files {
                if files.isEmpty {
                    ContentUnavailableView("No backups yet", systemImage: "externaldrive",
                                           description: Text("Tap Back Up Now to make your first one."))
                }
                ForEach(files) { file in
                    Button {
                        chosen = file
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.createdTime ?? .now, format: .dateTime.month(.wide).day().year().hour().minute())
                                .foregroundStyle(.primary)
                            Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))
                                .appFont(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(backup.isWorking)
                }
            } else if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }

            if let progress {
                Section {
                    ProgressView(value: progress) { Text(backup.status ?? "Restoring…") }
                }
            }
        }
        .navigationTitle("Restore")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { files = try await GoogleDrive.listBackups() } catch { loadError = error.localizedDescription }
        }
        .confirmationDialog("Restore this backup?", isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } }),
                            titleVisibility: .visible, presenting: chosen) { file in
            Button("Restore") { restore(file) }
        } message: { _ in
            Text("Entries from the backup are added to your journal. Entries you already have are skipped, and nothing is deleted.")
        }
        .alert(item: $alert) { info in
            Alert(title: Text(info.title), message: Text(info.message))
        }
    }

    private func restore(_ file: GoogleDrive.File) {
        progress = 0
        Task {
            do {
                let result = try await backup.restore(file) { value in
                    Task { @MainActor in progress = value }
                }
                progress = nil
                alert = AlertInfo(title: "Restore Complete",
                                  message: "\(result.imported) entries added. \(result.skippedDuplicates) were already in your journal.")
            } catch {
                progress = nil
                alert = AlertInfo(title: "Restore Failed", message: error.localizedDescription)
            }
        }
    }
}
