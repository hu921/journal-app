import SwiftUI
import SwiftData

/// Simple numbers about the journal.
struct StatsView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    private let cal = Calendar.current

    private var mediaCount: Int { entries.reduce(0) { $0 + ($1.media?.count ?? 0) } }
    private var dayStarts: Set<Date> { Set(entries.map { cal.startOfDay(for: $0.date) }) }

    /// Consecutive days with an entry, counting back from today (or yesterday).
    private var streak: Int {
        let days = dayStarts
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    /// Entries from today's date in earlier years.
    private var onThisDay: [JournalEntry] {
        let today = cal.dateComponents([.year, .month, .day], from: .now)
        return entries.filter {
            let c = cal.dateComponents([.year, .month, .day], from: $0.date)
            return c.month == today.month && c.day == today.day && c.year != today.year
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Streak banner across the top.
                    HStack(spacing: 14) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Writing streak").appFont(.subheadline, weight: .semibold)
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(streak) \(streak == 1 ? "day" : "days") in a row")
                                .appFont(.title2, weight: .bold)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16))

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        StatTile(title: "Entries", value: entries.count)
                        StatTile(title: "Days written", value: dayStarts.count)
                        StatTile(title: "Photos & videos", value: mediaCount)
                        NavigationLink {
                            OnThisDayView(entries: onThisDay)
                        } label: {
                            StatTile(title: "Memories", value: onThisDay.count, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Stats")
            .profileToolbar()
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: Int
    var unit: String? = nil
    var tall = false
    var showsChevron = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            if tall { Spacer() }
            Text(value, format: .number)
                .font(tall ? .system(size: 56, weight: .bold, design: .rounded)
                           : .system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(tall ? Color.accentColor : .primary)
            if let unit {
                Text(unit).appFont(.headline).foregroundStyle(.secondary)
            }
            if tall { Spacer() }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct OnThisDayView: View {
    let entries: [JournalEntry]

    var body: some View {
        List(entries) { entry in
            NavigationLink {
                EntryDetailView(entry: entry)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, format: .dateTime.year())
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(Color.accentColor)
                    EntryRow(entry: entry, showsDay: false)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("Nothing yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Entries from this date in past years show up here."))
            }
        }
        .navigationTitle("Memories")
    }
}
