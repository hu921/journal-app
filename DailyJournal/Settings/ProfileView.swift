import SwiftUI
import PhotosUI
import SwiftData

/// Edit everything on the About Me page. Every field is optional.
struct ProfileView: View {
    @Bindable var profile: UserProfile
    @State private var editingBirthday = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showSignature = false

    private static let defaultBirthday = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1))!

    private var birthday: Binding<Date> {
        Binding(get: { profile.birthday ?? Self.defaultBirthday }, set: { profile.birthday = $0 })
    }

    private var gender: Binding<Gender?> {
        Binding(get: { profile.gender }, set: { profile.gender = $0 })
    }

    /// Right-now fields stamp today's date when changed.
    private func rightNow(_ keyPath: ReferenceWritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { profile[keyPath: keyPath] = $0; profile.rightNowUpdated = .now }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    ProfileAvatar(initials: profile.initials, photo: profile.photo, size: 96)
                    HStack(spacing: 16) {
                        PhotosPicker(profile.photo == nil ? "Add Photo" : "Change Photo",
                                     selection: $photoItem, matching: .images)
                        if profile.photo != nil {
                            Button("Remove", role: .destructive) { profile.photo = nil }
                        }
                    }
                    .buttonStyle(.borderless)
                    .appFont(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Me") {
                TextField("First name", text: $profile.firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $profile.lastName)
                    .textContentType(.familyName)
                TextField("Nickname", text: $profile.nickname)

                birthdayRow

                Picker("Gender", selection: gender) {
                    Text("Not set").tag(Gender?.none)
                    ForEach(Gender.allCases) { g in
                        Text(g.label).tag(Optional(g))
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Favorites") {
                TextField("Food", text: $profile.favoriteFood)
                TextField("Color", text: $profile.favoriteColor)
                TextField("Song", text: $profile.favoriteSong)
                TextField("Movie", text: $profile.favoriteMovie)
                TextField("Book", text: $profile.favoriteBook)
                TextField("Place", text: $profile.favoritePlace)
                TextField("Season", text: $profile.favoriteSeason)
            }

            Section {
                TextField("For example: curious, calm, funny", text: $profile.threeWords)
            } header: {
                Text("Three words that describe me")
            }

            Section {
                TextField("Mood", text: rightNow(\.mood))
                TextField("What I'm into", text: rightNow(\.intoNow), axis: .vertical)
                TextField("This year's goals", text: rightNow(\.goals), axis: .vertical)
                if profile.hasRightNow {
                    Button("Save to Time Capsule and Start Fresh") {
                        profile.saveRightNowToCapsule()
                        profile.mood = ""
                        profile.intoNow = ""
                        profile.goals = ""
                        profile.rightNowUpdated = nil
                    }
                }
            } header: {
                Text("Right now")
            } footer: {
                Text("Once a year, save these to your time capsule and write new ones. Past answers stay on your About Me page.")
            }

            Section("Keepsake") {
                TextField("Favorite quote", text: $profile.quote, axis: .vertical)
                Button {
                    showSignature = true
                } label: {
                    HStack {
                        Text("Signature").foregroundStyle(.primary)
                        Spacer()
                        Text(profile.signature == nil ? "Add" : "Change")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Edit About Me")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    profile.photo = Self.smallJPEG(from: data)
                }
                photoItem = nil
            }
        }
        .sheet(isPresented: $showSignature) {
            SignatureSheet(signature: $profile.signature)
        }
    }

    // Birthday: a one-line row. Tap to open the wheel, tap Done to close it.
    @ViewBuilder private var birthdayRow: some View {
        Button {
            withAnimation {
                if profile.birthday == nil { profile.birthday = Self.defaultBirthday }
                editingBirthday.toggle()
            }
        } label: {
            HStack {
                Text("Birthday").foregroundStyle(.primary)
                Spacer()
                if let date = profile.birthday {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .foregroundStyle(editingBirthday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                } else {
                    Text("Add").foregroundStyle(.tint)
                }
            }
        }

        if editingBirthday {
            DatePicker("Birthday", selection: birthday, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            HStack {
                Button("Remove", role: .destructive) {
                    withAnimation {
                        profile.birthday = nil
                        editingBirthday = false
                    }
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Done") {
                    withAnimation { editingBirthday = false }
                }
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
            }
        }
    }

    /// Shrinks a photo to 600 px so the profile stays small in iCloud.
    static func smallJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side: CGFloat = 600
        let scale = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

/// Round icon with the person's photo, their initials, or a person symbol.
struct ProfileAvatar: View {
    let initials: String
    var photo: Data? = nil
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(.tint)
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if initials.isEmpty {
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
        .clipShape(Circle())
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
            ProfileAvatar(initials: profiles.first?.initials ?? "", photo: profiles.first?.photo)
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
