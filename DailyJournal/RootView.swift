import SwiftUI

/// Bottom tabs for the main sections of the app.
struct RootView: View {
    var body: some View {
        TabView {
            EntryListView()
                .tabItem { Label("List", systemImage: "list.bullet") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            EntryMapView()
                .tabItem { Label("Map", systemImage: "map") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
    }
}
