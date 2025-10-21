//
//  ContentView.swift
//  campus_compass
//
//  Created by Anna Tymoshenko on 10/6/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchBarView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            MapView()
                .tabItem { Label("Map", systemImage: "map") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.red)
    }
}

#Preview {
    ContentView()
}
