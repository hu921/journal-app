import SwiftUI
import SwiftData

/// Main screen: entries grouped by month, newest first.
struct EntryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var search = ""
    @State private var newEntry: JournalEntry?

    private var filtered: [JournalEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.body.localizedCaseInsensitiveContains(search) ||
            ($0.placeName ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    /// [(first day of month, entries in that month)], newest month first.
    private var months: [(Date, [JournalEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) {
            cal.date(from: cal.dateComponents([.year, .month], from: $0.date))!
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    ForEach(months, id: \.0) { month, monthEntries in
                        Section {
                            ForEach(Array(monthEntries.enumerated()), id: \.element.id) { index, entry in
                                NavigationLink {
                                    EntryDetailView(entry: entry)
                                } label: {
                                    EntryRow(entry: entry, showsDay: index == 0 ||
                                             !Calendar.current.isDate(entry.date, inSameDayAs: monthEntries[index - 1].date))
                                }
                            }
                            .onDelete { offsets in
                                for i in offsets { context.delete(monthEntries[i]) }
                            }
                        } header: {
                            Text(month, format: .dateTime.month(.wide).year())
                                .appFont(.title3, weight: .bold)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if entries.isEmpty {
                        ContentUnavailableView("No entries yet",
                                               systemImage: "book.closed",
                                               description: Text("Tap + to write your first entry."))
                    } else if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                }

                Button {
                    let entry = JournalEntry()
                    context.insert(entry)
                    newEntry = entry
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(radius: 4, y: 2)
                }
                .padding(24)
                .accessibilityLabel("New entry")
            }
            .navigationTitle("Journal")
            .profileToolbar()
            .searchable(text: $search)
            .sheet(item: $newEntry) { entry in
                NavigationStack { EntryEditorView(entry: entry, isNew: true) }
            }
        }
    }
}
