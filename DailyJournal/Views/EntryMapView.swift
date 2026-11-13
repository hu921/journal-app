import SwiftUI
import SwiftData
import MapKit

/// Map of every entry that has a location. Tap a pin to open the entry.
struct EntryMapView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var position: MapCameraPosition = .automatic
    @State private var selected: JournalEntry?

    private var located: [JournalEntry] {
        entries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(located) { entry in
                    Annotation(entry.displayTitle,
                               coordinate: CLLocationCoordinate2D(latitude: entry.latitude!,
                                                                  longitude: entry.longitude!)) {
                        MapPin(entry: entry)
                            .onTapGesture { selected = entry }
                    }
                }
            }
            .overlay {
                if located.isEmpty {
                    ContentUnavailableView("No places yet", systemImage: "map",
                                           description: Text("Entries with a location show up here."))
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(40)
                }
            }
            .navigationTitle("Map")
            .profileToolbar()
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selected) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }
}

private struct MapPin: View {
    let entry: JournalEntry

    var body: some View {
        Group {
            if let data = entry.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 2))
        .shadow(radius: 2)
    }
}
