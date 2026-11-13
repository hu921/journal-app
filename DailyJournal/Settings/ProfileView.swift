import SwiftUI
import SwiftData

/// Edit first name, last name, gender and birthday.
struct ProfileView: View {
    @Bindable var profile: UserProfile

    private var birthday: Binding<Date> {
        Binding(
            get: { profile.birthday ?? Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1))! },
            set: { profile.birthday = $0 }
        )
    }

    private var gender: Binding<Gender?> {
        Binding(get: { profile.gender }, set: { profile.gender = $0 })
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ProfileAvatar(initials: profile.initials, size: 88)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Name") {
                TextField("First name", text: $profile.firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $profile.lastName)
                    .textContentType(.familyName)
            }

            Section("Gender") {
                Picker("Gender", selection: gender) {
                    ForEach(Gender.allCases) { g in
                        Text(g.label).tag(Optional(g))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Birthday") {
                DatePicker("Birthday", selection: birthday, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Round icon with the person's initials, or a person symbol if no name yet.
struct ProfileAvatar: View {
    let initials: String
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(Color.accentColor)
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Top-right toolbar button that opens Settings.
struct ProfileButton: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @State private var editing: UserProfile?

    var body: some View {
        Button {
            if let existing = profiles.first {
                editing = existing
            } else {
                let profile = UserProfile()
                context.insert(profile)
                editing = profile
            }
        } label: {
            ProfileAvatar(initials: profiles.first?.initials ?? "")
        }
        .accessibilityLabel("Settings")
        .sheet(item: $editing) { profile in
            NavigationStack { SettingsView(profile: profile) }
                .appAppearance()
        }
    }
}

extension View {
    /// Adds the profile icon to the top-right of a screen.
    func profileToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) { ProfileButton() }
        }
    }
}
