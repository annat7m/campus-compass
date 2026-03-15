import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var buildingStore = BuildingStore()

    @State private var settingsPath = NavigationPath()
    @State private var showWelcome = true

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
                    
                    do {
                            try modelContext.save()
                            print("Created and saved profile: \(p.name)")
                        } catch {
                            print("Failed to save profile: \(error)")
                        }
                }
            }
        }
        .onAppear {
            print("Profiles found locally: \(profiles.count)")
            if let first = profiles.first {
                print("First profile name: \(first.name)")
            }
        }
        .environmentObject(appState)
        .environmentObject(buildingStore)
        .task {
            if buildingStore.buildings.isEmpty {
                await buildingStore.fetchBuildings()
            }
        }
    }

    @ViewBuilder
    private func mainTabs(profile: UserProfile) -> some View {
        ZStack {
            TabView(selection: $appState.selectedTab) {
                HomeView(profile: profile)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                MapView()
                    .tabItem { Label("Map", systemImage: "map") }
                    .tag(1)

                NavigationStack(path: $settingsPath) {
                    SettingsView(selectedTab: $appState.selectedTab, profile: profile, settingsPath: $settingsPath)
                }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
            }
            .tint(.red)
            .opacity(showWelcome ? 0 : 1)
            .scaleEffect(showWelcome ? 0.98 : 1)
            .blur(radius: showWelcome ? 8 : 0)
            .animation(.easeOut(duration: 0.6), value: showWelcome)
            .allowsHitTesting(!showWelcome)

            if showWelcome {
                WelcomeSplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.6), value: showWelcome)
        .task {
            guard showWelcome else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.6)) {
                showWelcome = false
            }
        }
    }
}
