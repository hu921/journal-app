import SwiftUI
import SwiftData

/// Month grids. Days with entries show the first photo, or a dot if there is none.
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var selectedDay: DaySelection?
    @State private var newEntry: JournalEntry?

    private let cal = Calendar.current

    /// Entries keyed by start of day.
    private var byDay: [Date: [JournalEntry]] {
        Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
    }

    /// Every month from the oldest entry to the current month, oldest first.
    private var months: [Date] {
        let now = cal.dateInterval(of: .month, for: .now)!.start
        let first = entries.last.map { cal.dateInterval(of: .month, for: $0.date)!.start } ?? now
        var result: [Date] = []
        var m = min(first, now)
        while m <= now {
            result.append(m)
            m = cal.date(byAdding: .month, value: 1, to: m)!
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(months, id: \.self) { month in
                                MonthGrid(month: month, byDay: byDay) { day in
                                    selectedDay = DaySelection(date: day)
                                }
                                .id(month)
                            }
                        } header: {
                            WeekdayHeader()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 20)
                }
                .onAppear { proxy.scrollTo(months.last, anchor: .bottom) }
            }
            .navigationTitle("Calendar")
            .profileToolbar()
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedDay) { day in
                DayEntriesView(day: day.date, entries: byDay[day.date] ?? []) {
                    let entry = JournalEntry(date: Self.dateAtCurrentTime(on: day.date))
                    context.insert(entry)
                    newEntry = entry
                }
            }
            .sheet(item: $newEntry) { entry in
                NavigationStack { EntryEditorView(entry: entry, isNew: true) }
            }
        }
    }

    /// The chosen day, at the current time of day.
    static func dateAtCurrentTime(on day: Date) -> Date {
        let cal = Calendar.current
        let time = cal.dateComponents([.hour, .minute], from: .now)
        return cal.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) ?? day
    }
}

struct DaySelection: Hashable, Identifiable {
    let date: Date
    var id: Date { date }
}

private struct WeekdayHeader: View {
    var body: some View {
        let symbols = Calendar.current.shortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        HStack(spacing: 2) {
            ForEach(ordered, id: \.self) { s in
                Text(s.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(.bar)
    }
}

private struct MonthGrid: View {
    let month: Date
    let byDay: [Date: [JournalEntry]]
    var onSelect: (Date) -> Void

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var days: [Date?] {
        let range = cal.range(of: .day, in: .month, for: month)!
        let weekday = cal.component(.weekday, from: month)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        let dates = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + dates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.title3.bold())
                .padding(.horizontal, 4)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(day: day, entries: byDay[day] ?? [])
                            .onTapGesture { onSelect(day) }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let entries: [JournalEntry]

    private var thumbnail: UIImage? {
        entries.lazy.compactMap { $0.thumbnailData }.first.flatMap(UIImage.init(data:))
    }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        ZStack {
            if let thumbnail {
                Color.clear.overlay {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                }
                .clipped()
                .overlay(Color.black.opacity(0.25))
            } else {
                Rectangle().fill(isToday ? Color.accentColor : Color(.secondarySystemBackground))
            }
            VStack(spacing: 2) {
                Text(day, format: .dateTime.day())
                    .font(.headline)
                    .foregroundStyle(thumbnail != nil || isToday ? .white : .primary)
                if thumbnail == nil && !entries.isEmpty {
                    Circle().fill(isToday ? Color.white : Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

/// Entries for one day, with a button to add another.
struct DayEntriesView: View {
    let day: Date
    let entries: [JournalEntry]
    var onAdd: () -> Void

    var body: some View {
        List {
            ForEach(entries.sorted { $0.date > $1.date }) { entry in
                NavigationLink {
                    EntryDetailView(entry: entry)
                } label: {
                    EntryRow(entry: entry, showsDay: false)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("No entries", systemImage: "square.and.pencil",
                                       description: Text("Tap + to write about this day."))
            }
        }
        .navigationTitle(Text(day, format: .dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(action: onAdd) { Image(systemName: "plus") }
                .accessibilityLabel("New entry for this day")
        }
    }
}
