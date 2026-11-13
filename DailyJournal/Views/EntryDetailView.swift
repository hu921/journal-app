import SwiftUI
import AVKit

/// Read-only view of an entry, with media at the top.
struct EntryDetailView: View {
    let entry: JournalEntry
    @State private var isEditing = false
    @State private var playingVideo: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !entry.sortedMedia.isEmpty {
                    TabView {
                        ForEach(entry.sortedMedia) { item in
                            mediaPage(item)
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 300)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.date, format: .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let place = entry.placeName {
                        Label(place, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !entry.title.isEmpty {
                        Text(entry.title).font(.title2.bold())
                    }
                    Text(entry.body)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack { EntryEditorView(entry: entry) }
        }
        .fullScreenCover(item: $playingVideo) { url in
            VideoPlayerScreen(url: url)
        }
    }

    @ViewBuilder
    private func mediaPage(_ item: MediaItem) -> some View {
        switch item.kind {
        case .photo:
            if let data = item.data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            }
        case .video:
            Button {
                if let data = item.data { playingVideo = MediaLoader.tempURL(forVideo: data) }
            } label: {
                MediaThumbnail(item: item)
            }
            .buttonStyle(.plain)
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct VideoPlayerScreen: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player).ignoresSafeArea()
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            .padding()
        }
        .onAppear {
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            try? FileManager.default.removeItem(at: url)
        }
    }
}
