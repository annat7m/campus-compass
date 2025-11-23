//
//  campus_compassApp.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/6/25.
//

import SwiftUI
import SwiftData

@main
struct campus_compassApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: UserProfile.self)
    }
}
