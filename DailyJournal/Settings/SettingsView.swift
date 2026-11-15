import SwiftUI

/// Settings home: About Me, Appearance, Import/Export, About.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile

    private var profileSubtitle: String {
        let name = "\(profile.firstName) \(profile.lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Add your name" : name
    }

    @AppStorage("iCloudSyncOn") private var iCloudOn = true
    @ObservedObject private var backup = BackupManager.shared
    @ObservedObject private var syncMonitor = SyncMonitor.shared

    private var syncOn: Bool { iCloudOn || backup.isOn }

    /// The latest of the iCloud sync and the Google Drive backup.
    private var lastSync: Date? {
        [iCloudOn ? syncMonitor.lastICloudSync : nil, backup.isOn ? backup.lastBackup : nil]
            .compactMap { $0 }.max()
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AboutMeView(profile: profile)
                } label: {
                    HStack(spacing: 14) {
                        ProfileAvatar(initials: profile.initials, photo: profile.photo, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("About Me").appFont(.headline)
                            Text(profileSubtitle).appFont(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                NavigationLink { BackupView() } label: {
                    LabeledContent {
                        Text(syncOn ? "On" : "Off")
                    } label: {
                        Label("Sync", systemImage: "icloud")
                    }
                }
                LabeledContent {
                    if let last = lastSync {
                        Text(last, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    } else {
                        Text("Not yet")
                    }
                } label: {
                    Label("Last Sync", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Section {
                NavigationLink { AppearanceView() } label: {
                    Label("Appearance", systemImage: "paintbrush")
                }
                NavigationLink { PasscodeSettingsView() } label: {
                    Label("Passcode", systemImage: "lock")
                }
                NavigationLink { ImportExportView() } label: {
                    Label("Import / Export", systemImage: "arrow.up.arrow.down")
                }
                NavigationLink { AboutView() } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
