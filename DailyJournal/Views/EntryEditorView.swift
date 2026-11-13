import SwiftUI
import SwiftData
import PhotosUI

/// Create or edit an entry: title, text, date-time, location, photos and videos.
struct EntryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: JournalEntry
    var isNew = false

    @StateObject private var location = LocationService()
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var videoItems: [PhotosPickerItem] = []
    @State private var isLoadingMedia = false
    @State private var isLocating = false

    private var photosLeft: Int { JournalEntry.maxPhotos - entry.photos.count }
    private var videosLeft: Int { JournalEntry.maxVideos - entry.videos.count }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $entry.title)
                    .font(.headline)
                TextField("What happened today?", text: $entry.body, axis: .vertical)
                    .lineLimit(6...)
            }

            Section {
                DatePicker("Date", selection: $entry.date)
                HStack {
                    Label(entry.placeName ?? "No location", systemImage: "mappin.and.ellipse")
                        .foregroundStyle(entry.placeName == nil ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    if isLocating {
                        ProgressView()
                    } else if entry.placeName == nil {
                        Button("Add") { addLocation() }
                    } else {
                        Button("Remove", role: .destructive) {
                            entry.placeName = nil
                            entry.latitude = nil
                            entry.longitude = nil
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
        .interactiveDismissDisabled(isNew)
        .navigationTitle(isNew ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        context.delete(entry)
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: photoItems) { _, items in add(items, limit: photosLeft); photoItems = [] }
        .onChange(of: videoItems) { _, items in add(items, limit: videosLeft); videoItems = [] }
        .task {
            // New entries pick up the current location automatically.
            if isNew && entry.placeName == nil { addLocation() }
        }
    }

    private func addLocation() {
        isLocating = true
        Task {
            if let place = await location.currentPlace() {
                entry.placeName = place.name
                entry.latitude = place.latitude
                entry.longitude = place.longitude
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
