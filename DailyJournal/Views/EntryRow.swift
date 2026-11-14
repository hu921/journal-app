import SwiftUI

/// One row: weekday + day on the left, title and "time · place" in the middle,
/// thumbnail on the right. The day column is hidden for later entries on the same day.
struct EntryRow: View {
    let entry: JournalEntry
    var showsDay = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                if showsDay {
                    Text(entry.date, format: .dateTime.weekday(.abbreviated))
                        .appFont(.caption, weight: .semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(entry.date, format: .dateTime.day(.twoDigits))
                        .appFont(.title2, weight: .medium)
                        .monospacedDigit()
                }
            }
            .frame(width: 40)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.displayTitle)
                    .appFont(.headline)
                    .lineLimit(3)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text(entry.date, format: .dateTime.hour().minute())
                    if let place = entry.placeName, !place.isEmpty {
                        Text("·")
                        Text(place).lineLimit(1)
                    }
                }
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if entry.hasMedia {
                EntryThumbnail(entry: entry)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(minHeight: 72)
        .padding(.vertical, 6)
    }
}
