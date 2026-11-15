import SwiftUI

/// Bottom tabs for the main sections of the app.
struct RootView: View {
    enum Tab: Hashable { case list, calendar, map, stats }
    @State private var tab: Tab = .list
    @Environment(\.scenePhase) private var scenePhase
    @State private var leftAt: Date?
    /// Changing this rebuilds the Logs tab: back to its first screen, scrolled to the top.
    @State private var logsID = UUID()

    /// Away this long or more, the app opens fresh on Logs. A quick switch to
    /// another app (to copy something, say) keeps your place.
    private static let resetAfter: TimeInterval = 60

    var body: some View {
        // Map and Stats are only built while shown. A hidden tab still redraws
        // whenever any entry changes, and these two do the most work (issue #3).
        TabView(selection: $tab) {
            EntryListView()
                .id(logsID)
                .tabItem { Label("Logs", systemImage: "list.bullet") }
                .tag(Tab.list)
            CalendarView()
                .tabItem { Label("Days", systemImage: "calendar") }
                .tag(Tab.calendar)
            Group { if tab == .map { EntryMapView() } else { Color.clear } }
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)
            Group { if tab == .stats { StatsView() } else { Color.clear } }
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(Tab.stats)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                leftAt = .now
            case .active:
                defer { leftAt = nil }
                guard let leftAt, Date.now.timeIntervalSince(leftAt) >= Self.resetAfter else { return }
                // Never close an entry that is being written.
                guard EditorTracker.openCount == 0 else { return }
                AppLog.info("Back after \(Int(Date.now.timeIntervalSince(leftAt)))s: opening Logs at the top")
                tab = .list
                logsID = UUID()
            default:
                break
            }
        }
    }
}
