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

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(session: session)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            MapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(1)

            NavigationStack {
                SettingsView(selectedTab: $selectedTab, session: session)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(2)
        }
        .tint(.red)
    }
}

