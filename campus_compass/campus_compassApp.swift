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
        .modelContainer(makeModelContainer())
    }

    private func makeModelContainer() -> ModelContainer {
        do {
            let schema = Schema([UserProfile.self])

            // IMPORTANT: replace with YOUR iCloud container identifier
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.edu.pacificu.cs.campus-compass")
            )

            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
