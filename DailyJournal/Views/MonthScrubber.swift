import SwiftUI

/// A handle on the right edge for jumping through months quickly.
/// Drag it to move; a label shows the month, and years are marked along the track.
struct MonthScrubber: View {
    /// Months shown in the scroll view, oldest first.
    let months: [Date]
    /// The month currently at the top of the scroll view.
    let current: Date?
    /// True while the person is dragging the handle.
    @Binding var isDragging: Bool
    var onSelect: (Date) -> Void

    @State private var dragMonth: Date?

    private let handleSize = CGSize(width: 34, height: 44)
    private let cal = Calendar.current

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let shown = dragMonth ?? current
            let index = shown.flatMap { months.firstIndex(of: $0) } ?? max(months.count - 1, 0)
            let handleY = y(for: index, height: height)

            ZStack(alignment: .topLeading) {
                // Year marks along the track, only while dragging.
                ForEach(yearMarks(height: height), id: \.year) { mark in
                    Text(String(mark.year))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                        .position(x: geo.size.width - handleSize.width - 30, y: mark.y)
                        .allowsHitTesting(false)
                }
                .opacity(isDragging ? 1 : 0)

                // Month label next to the handle while dragging.
                if isDragging, let shown {
                    Text(shown, format: .dateTime.month(.abbreviated).year())
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .fixedSize()
                        .position(x: geo.size.width - handleSize.width - 90, y: handleY)
                        .allowsHitTesting(false)
                }

                // The handle.
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isDragging ? .white : .secondary)
                    .frame(width: handleSize.width, height: handleSize.height)
                    .background(isDragging ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                                in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: -1, y: 1)
                    .position(x: geo.size.width - handleSize.width / 2, y: handleY)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("scrubber"))
                            .onChanged { value in
                                isDragging = true
                                let picked = month(at: value.location.y, height: height)
                                if picked != dragMonth {
                                    dragMonth = picked
                                    onSelect(picked)
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                dragMonth = nil
                            }
                    )
                    .accessibilityLabel("Scroll by month")
            }
            .coordinateSpace(name: "scrubber")
            .sensoryFeedback(.selection, trigger: dragMonth)
        }
    }

    private func y(for index: Int, height: CGFloat) -> CGFloat {
        let usable = max(height - handleSize.height, 1)
        let fraction = months.count > 1 ? CGFloat(index) / CGFloat(months.count - 1) : 1
        return handleSize.height / 2 + fraction * usable
    }

    private func month(at y: CGFloat, height: CGFloat) -> Date {
        let usable = max(height - handleSize.height, 1)
        let fraction = min(max((y - handleSize.height / 2) / usable, 0), 1)
        let index = Int((fraction * CGFloat(months.count - 1)).rounded())
        return months[min(max(index, 0), months.count - 1)]
    }

    /// One mark per year at its first month, skipping marks that would overlap.
    private func yearMarks(height: CGFloat) -> [(year: Int, y: CGFloat)] {
        var marks: [(year: Int, y: CGFloat)] = []
        var lastYear: Int?
        for (i, month) in months.enumerated() {
            let year = cal.component(.year, from: month)
            guard year != lastYear else { continue }
            lastYear = year
            let markY = y(for: i, height: height)
            if let previous = marks.last, markY - previous.y < 22 { continue }
            marks.append((year, markY))
        }
        return marks
    }
}
