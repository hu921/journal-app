import SwiftUI

/// Settings home: Profile, Appearance, Import/Export, About.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile

    private var profileSubtitle: String {
        let name = "\(profile.firstName) \(profile.lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Add your name" : name
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProfileView(profile: profile)
                } label: {
                    HStack(spacing: 14) {
                        ProfileAvatar(initials: profile.initials, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Profile").appFont(.headline)
                            Text(profileSubtitle).appFont(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
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
