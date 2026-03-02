//
//  ContentView.swift
//  campus_compass
//
//  Created by Anna Tymoshenko on 10/6/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var session = UserSession()
    @State private var settingsPath = NavigationPath()
    @State private var showWelcome = true

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(session: session)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                MapView()
                    .tabItem { Label("Map", systemImage: "map") }
                    .tag(1)

                NavigationStack(path: $settingsPath) {
                    SettingsView(selectedTab: $selectedTab, session: session, settingsPath: $settingsPath)
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
