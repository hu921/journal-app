import SwiftUI

/// Bottom tabs for the main sections of the app.
struct RootView: View {
    enum Tab: Hashable { case list, calendar, map, stats }
    @State private var tab: Tab = .list

    var body: some View {
        // Map and Stats are only built while shown. A hidden tab still redraws
        // whenever any entry changes, and these two do the most work (issue #3).
        TabView(selection: $tab) {
            EntryListView()
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
    }
}
