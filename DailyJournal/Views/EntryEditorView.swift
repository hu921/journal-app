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
    @StateObject private var location = LocationService()
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var videoItems: [PhotosPickerItem] = []
    @State private var isLoadingMedia = false
    @State private var isLocating = false

    // Text, date and place are edited as a local draft and saved on Done.
    // Writing to the saved entry on every keystroke made every tab redraw (issue #3).
    @State private var draftTitle: String
    @State private var draftBody: String
    @State private var draftDate: Date
    @State private var draftPlace: String?
    @State private var draftLatitude: Double?
    @State private var draftLongitude: Double?
    @FocusState private var bodyFocused: Bool

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
                    Label(draftPlace ?? "No location", systemImage: "mappin.and.ellipse")
                        .foregroundStyle(draftPlace == nil ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    if isLocating {
                        ProgressView()
                    } else if draftPlace == nil {
                        Button("Add") { addLocation() }
                    } else {
                        Button("Remove", role: .destructive) {
                            draftPlace = nil
                            draftLatitude = nil
                            draftLongitude = nil
                        }
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
                    if isNew { context.delete(entry) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { save() }
            }
        }
        .onChange(of: photoItems) { _, items in add(items, limit: photosLeft); photoItems = [] }
        .onChange(of: videoItems) { _, items in add(items, limit: videosLeft); videoItems = [] }
        .task {
            // New entries pick up the current location automatically.
            if isNew && draftPlace == nil { addLocation() }
            if isNew { bodyFocused = true }
        }
    }

    private func save() {
        if entry.title != draftTitle { entry.title = draftTitle }
        if entry.body != draftBody { entry.body = draftBody }
        if entry.date != draftDate { entry.date = draftDate }
        if entry.placeName != draftPlace {
            entry.placeName = draftPlace
            entry.latitude = draftLatitude
            entry.longitude = draftLongitude
        }
        try? context.save()
        dismiss()
    }

    private func addLocation() {
        isLocating = true
        Task {
            if let place = await location.currentPlace() {
                draftPlace = place.name
                draftLatitude = place.latitude
                draftLongitude = place.longitude
            }
            isLocating = false
        }
    }

    private func add(_ items: [PhotosPickerItem], limit: Int) {
        guard !items.isEmpty, limit > 0 else { return }
        isLoadingMedia = true
        Task {
            var nextOrder = (entry.sortedMedia.last?.order ?? -1) + 1
            for item in items.prefix(limit) {
                guard let loaded = await MediaLoader.load(item) else { continue }
                let media = MediaItem(kind: loaded.kind, data: loaded.data,
                                      thumbnail: loaded.thumbnail, order: nextOrder)
                context.insert(media)
                media.entry = entry
                nextOrder += 1
            }
            isLoadingMedia = false
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
