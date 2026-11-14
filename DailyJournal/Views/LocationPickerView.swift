import SwiftUI
import MapKit

/// Search for a place, or use the current location.
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (LocationService.Place) -> Void

    @StateObject private var search = PlaceSearch()
    @StateObject private var location = LocationService()
    @State private var isWorking = false

    var body: some View {
        List {
            Section {
                Button {
                    pickCurrent()
                } label: {
                    Label("Use Current Location", systemImage: "location.fill")
                }
                .disabled(isWorking)
            }

            if !search.results.isEmpty {
                Section("Results") {
                    ForEach(search.results, id: \.self) { result in
                        Button {
                            pick(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title).foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle).appFont(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(isWorking)
                    }
                }
            }
        }
        .overlay { if isWorking { ProgressView() } }
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search a place or address")
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func pickCurrent() {
        isWorking = true
        Task {
            if let place = await location.currentPlace() {
                onPick(place)
                dismiss()
            }
            isWorking = false
        }
    }

    private func pick(_ completion: MKLocalSearchCompletion) {
        isWorking = true
        Task {
            let request = MKLocalSearch.Request(completion: completion)
            if let item = try? await MKLocalSearch(request: request).start().mapItems.first {
                let coord = item.placemark.coordinate
                let name = [completion.title, item.placemark.locality]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                    .joined(separator: ", ")
                onPick(.init(name: name, latitude: coord.latitude, longitude: coord.longitude))
                dismiss()
            }
            isWorking = false
        }
    }
}

/// Live place suggestions as the person types.
@MainActor
final class PlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { completer.queryFragment = query } }
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.results = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }
}
