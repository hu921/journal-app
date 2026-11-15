import SwiftUI
import SwiftData
import PhotosUI

/// Create or edit an entry: title, text, date-time, location, photos and videos.
struct EntryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: JournalEntry
    var isNew = false

    @AppStorage(SettingsKey.autoTitleFirstLine) private var autoTitle = true
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var videoItems: [PhotosPickerItem] = []
    @State private var isLoadingMedia = false
    @State private var isLocating = false
    @State private var showLocationPicker = false
    @State private var photoSuggestion: PhotoSuggestion?

    // Text, date and place are edited as a local draft and saved on Done.
    // Writing to the saved entry on every keystroke made every tab redraw (issue #3).
    @State private var draftTitle: String
    @State private var draftBody: String
    @State private var draftDate: Date
    @State private var draftPlace: String?
    @State private var draftLatitude: Double?
    @State private var draftLongitude: Double?
    @FocusState private var bodyFocused: Bool
    @State private var loggedLines = 0

    init(entry: JournalEntry, isNew: Bool = false) {
        _entry = Bindable(entry)
        self.isNew = isNew
        _draftTitle = State(initialValue: entry.title)
        _draftBody = State(initialValue: entry.body)
        _draftDate = State(initialValue: entry.date)
        _draftPlace = State(initialValue: entry.placeName)
        _draftLatitude = State(initialValue: entry.latitude)
        _draftLongitude = State(initialValue: entry.longitude)
    }

    private var hasChanges: Bool {
        draftTitle != entry.title || draftBody != entry.body || draftDate != entry.date
            || draftPlace != entry.placeName
    }

    private var photosLeft: Int { JournalEntry.maxPhotos - entry.photos.count }
    private var videosLeft: Int { JournalEntry.maxVideos - entry.videos.count }

    var body: some View {
        Form {
            Section {
                if !autoTitle {
                    TextField("Title", text: $draftTitle)
                        .appFont(.headline)
                }
                ZStack(alignment: .topLeading) {
                    if draftBody.isEmpty {
                        Text("What happened today?")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $draftBody)
                        .focused($bodyFocused)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                }
            }

            Section {
                DatePicker("Date", selection: $draftDate)
                HStack {
                    Button {
                        showLocationPicker = true
                    } label: {
                        Label(draftPlace ?? "Add location", systemImage: "mappin.and.ellipse")
                            .foregroundStyle(draftPlace == nil ? Color.accentColor : .primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if isLocating {
                        ProgressView()
                    } else if draftPlace != nil {
                        Button("Change") { showLocationPicker = true }
                            .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            draftPlace = nil
                            draftLatitude = nil
                            draftLongitude = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove location")
                    }
                }
            }

            Section {
                if !entry.sortedMedia.isEmpty {
                    MediaGrid(items: entry.sortedMedia) { item in
                        context.delete(item)
                    }
                }
                PhotosPicker(selection: $photoItems,
                             maxSelectionCount: max(photosLeft, 1),
                             matching: .images) {
                    Label("Add photos (\(entry.photos.count)/\(JournalEntry.maxPhotos))", systemImage: "photo")
                }
                .disabled(photosLeft <= 0 || isLoadingMedia)

                PhotosPicker(selection: $videoItems,
                             maxSelectionCount: max(videosLeft, 1),
                             matching: .videos) {
                    Label("Add videos (\(entry.videos.count)/\(JournalEntry.maxVideos))", systemImage: "video")
                }
                .disabled(videosLeft <= 0 || isLoadingMedia)

                if isLoadingMedia {
                    HStack { ProgressView(); Text("Adding media…").foregroundStyle(.secondary) }
                }
            } header: {
                Text("Media")
            }
        }
        .interactiveDismissDisabled(isNew || hasChanges)
        .navigationTitle(isNew ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    AppLog.info("Editor cancel")
                    if isNew {
                        context.delete(entry)
                        try? context.save()
                    }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { save() }
            }
        }
        .onAppear {
            AppLog.info("Editor opened (\(isNew ? "new" : "existing") entry, \(draftBody.count) chars, \(entry.media?.count ?? 0) media), memory \(AppLog.memoryMB()) MB")
        }
        .onChange(of: draftBody) { _, text in
            // Log when the line count changes, to trace typing problems. Never logs the text itself.
            let lines = text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            if lines != loggedLines {
                AppLog.info("Typing: now \(lines) lines, \(text.count) chars, memory \(AppLog.memoryMB()) MB")
                loggedLines = lines
            }
        }
        .onChange(of: photoItems) { _, items in add(items, limit: photosLeft); photoItems = [] }
        .onChange(of: videoItems) { _, items in add(items, limit: videosLeft); videoItems = [] }
        .task {
            // New entries start with no location. It comes from a photo or is added by hand.
            if isNew { bodyFocused = true }
        }
        .sheet(isPresented: $showLocationPicker) {
            NavigationStack {
                LocationPickerView { place in setPlace(place) }
            }
        }
        .alert("Use photo's date, time and location?",
               isPresented: Binding(get: { photoSuggestion != nil }, set: { if !$0 { photoSuggestion = nil } }),
               presenting: photoSuggestion) { suggestion in
            Button("Use") { apply(suggestion) }
            Button("Keep Current", role: .cancel) {}
        } message: { suggestion in
            Text(suggestion.summary)
        }
    }

    private func save() {
        AppLog.info("Editor save: \(draftBody.count) chars")
        if entry.title != draftTitle { entry.title = draftTitle }
        if entry.body != draftBody { entry.body = draftBody }
        if entry.date != draftDate { entry.date = draftDate }
        if entry.placeName != draftPlace {
            entry.placeName = draftPlace
            entry.latitude = draftLatitude
            entry.longitude = draftLongitude
        }
        do {
            try AppLog.measure("Save entry") { try context.save() }
        } catch {
            AppLog.error("Save failed: \(error)")
        }
        dismiss()
    }

    private func setPlace(_ place: LocationService.Place) {
        draftPlace = place.name
        draftLatitude = place.latitude
        draftLongitude = place.longitude
    }

    private func apply(_ suggestion: PhotoSuggestion) {
        if let date = suggestion.date { draftDate = date }
        if let place = suggestion.place { setPlace(place) }
        AppLog.info("Applied photo date/location")
    }

    /// After adding media, offer the first photo's date and place, if it has them
    /// and they differ from what the entry has now.
    private func suggest(from loaded: [MediaLoader.Loaded]) async {
        guard let source = loaded.first(where: { $0.takenAt != nil || $0.coordinate != nil }) else { return }
        var date = source.takenAt
        if let d = date, abs(d.timeIntervalSince(draftDate)) < 60 { date = nil }
        var place: LocationService.Place?
        if let coord = source.coordinate {
            let same = draftLatitude.map { abs($0 - coord.latitude) < 0.0005 } == true
                && draftLongitude.map { abs($0 - coord.longitude) < 0.0005 } == true
            if !same {
                isLocating = true
                place = await LocationService.place(for: coord)
                isLocating = false
            }
        }
        guard date != nil || place != nil else { return }
        photoSuggestion = PhotoSuggestion(date: date, place: place)
    }

    private func add(_ items: [PhotosPickerItem], limit: Int) {
        guard !items.isEmpty, limit > 0 else { return }
        isLoadingMedia = true
        Task {
            var nextOrder = (entry.sortedMedia.last?.order ?? -1) + 1
            var allLoaded: [MediaLoader.Loaded] = []
            for item in items.prefix(limit) {
                guard let loaded = await MediaLoader.load(item) else { continue }
                allLoaded.append(loaded)
                let media = MediaItem(kind: loaded.kind, data: loaded.data,
                                      thumbnail: loaded.thumbnail, order: nextOrder)
                context.insert(media)
                media.entry = entry
                nextOrder += 1
            }
            isLoadingMedia = false
            AppLog.info("Added \(allLoaded.count) media; with date \(allLoaded.filter { $0.takenAt != nil }.count), with location \(allLoaded.filter { $0.coordinate != nil }.count)")
            await suggest(from: allLoaded)
        }
    }
}

/// Small grid of thumbnails with a remove button on each.
struct MediaGrid: View {
    let items: [MediaItem]
    var onRemove: (MediaItem) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(items) { item in
                ZStack(alignment: .topTrailing) {
                    MediaThumbnail(item: item)
                        .frame(height: 80)
                    Button {
                        onRemove(item)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MediaThumbnail: View {
    let item: MediaItem

    var body: some View {
        ZStack {
            if let data = item.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
            }
            if item.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

/// What the "new entry" sheet shows. Its id never changes, unlike a model's id,
/// which changes when SwiftData first saves the entry. That change made the
/// sheet close and reopen empty while typing.
struct EditorTarget: Identifiable {
    let id = UUID()
    let entry: JournalEntry
}

/// Date and place found in a newly added photo or video.
struct PhotoSuggestion {
    let date: Date?
    let place: LocationService.Place?

    var summary: String {
        var lines: [String] = []
        if let date { lines.append(date.formatted(date: .abbreviated, time: .shortened)) }
        if let place { lines.append(place.name) }
        return lines.joined(separator: "\n")
    }
}
