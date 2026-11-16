import SwiftUI

/// One row: weekday + day on the left, the title in the middle, thumbnail on the right.
/// Kept compact: no time or place line. The day column is hidden for later entries on the same day.
struct EntryRow: View {
    let entry: JournalEntry
    var showsDay = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                if showsDay {
                    Text(entry.date, format: .dateTime.weekday(.abbreviated))
                        .appFont(.caption2, weight: .semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(entry.date, format: .dateTime.day(.twoDigits))
                        .appFont(.title3, weight: .medium)
                        .monospacedDigit()
                }
            }
            .frame(width: 36)

            Text(entry.displayTitle)
                .appFont(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if entry.hasMedia {
                EntryThumbnail(entry: entry)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(minHeight: 52)
        .padding(.vertical, 2)
    }
}
