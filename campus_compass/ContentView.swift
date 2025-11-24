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

    var body: some View {
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
    }
}

