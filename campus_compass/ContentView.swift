import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var buildingStore = BuildingStore()

    @State private var selectedTab = 0
    @State private var settingsPath = NavigationPath()

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                mainTabs(profile: profile)
            } else {
                OnboardingView { name in
                    let p = UserProfile(name: name)
                    modelContext.insert(p)
                    try? modelContext.save()
                }
            }
        }
        .environmentObject(appState)
        .environmentObject(buildingStore)
        .task {
            if buildingStore.buildings.isEmpty {
                await buildingStore.fetchBuildings()
            }
        }
        .tint(.red)
    }

    @ViewBuilder
    private func mainTabs(profile: UserProfile) -> some View {
        TabView(selection: $appState.selectedTab) {
            HomeView(profile: profile)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            MapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(1)

            NavigationStack(path: $settingsPath) {
                SettingsView(selectedTab: $selectedTab, profile: profile, settingsPath: $settingsPath)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(2)
        }
    }
}
