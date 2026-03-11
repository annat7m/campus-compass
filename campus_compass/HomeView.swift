//
//  HomeView.swift
//  Campus Compass
//
//  Purpose:
//  Home/dashboard screen components for the Campus Compass app. This file contains
//  reusable menu UI building blocks (sections + action buttons) and the main HomeView.
//
//  Key responsibilities:
//  - Display app branding and an entry point to navigation features.
//  - Show menu sections like Quick Actions, Popular Destinations, Recent Locations.
//  - Conditionally show Favorites based on the current logged-in user in UserSession.
//
//  Dependencies:
//  - SwiftUI
//  - UserSession (provides currentUser and favorites)
//  - User model is expected to include: name (String) and favorites ([String]).
//
//  Notes:
//  - Actions are currently placeholders (print statements). Replace with NavigationLinks
//    or routing when destination screens are implemented.
//  - SearchBarView is currently non-functional (TextField uses a constant binding).
//

import SwiftUI
import CloudKit

/// A simple search input UI used on the Home screen.
///
/// - Note: Currently uses a constant binding, so typing will not persist.
///   Convert to a `@Binding var searchText: String` when wiring up search.
struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        TextField("Search buildings...", text: $searchText)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding().background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .padding()
    }
}

/// A reusable section container for menu-like content on the Home screen.
///
/// Displays a title and a vertical list of `ActionButton`s when `items` is provided.
/// If `items` is nil or empty, a placeholder message is shown instead.
///
/// - Parameters:
///   - title: The section header text.
///   - items: Optional menu items to display as buttons.
///   - message: Optional placeholder text when there are no items.
struct MenuSectionView: View {
    var title: String
    var items: [MenuItem]?
    var message: String? = nil   // NEW (optional)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {

                if let items = items, !items.isEmpty {
                    // Display the items
                    ForEach(items) { item in
                        ActionButton(
                            title: item.title,
                            systemImage: item.systemImage,
                            action: item.action
                        )
                    }
                } else {
                    // Display placeholder message
                    Text(message ?? "No items")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .padding()
    }
}


/// A lightweight model representing a tappable row in a menu section.
///
/// Each item has a title, SF Symbol name, and an action closure.
/// `id` is generated automatically for SwiftUI diffing.
struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}


/// The scrollable collection of menu sections shown on the Home screen.
///
/// Uses `UserSession` to determine whether to display Favorites:
/// - If no user is logged in: show a message prompting login.
/// - If user logged in but favorites empty: show a "No buildings saved" message.
/// - Otherwise: map favorites strings into `MenuItem` buttons.
struct MenuView: View {
    var profile: UserProfile
    @EnvironmentObject private var appState: AppState
    var body: some View {
        ScrollView {
            MenuSectionView(
                title: "Quick Actions",
                items: [
                    MenuItem(
                        title: "View Campus Map",
                        systemImage: "map",
                        action: {
                            appState.selectedBuildingID = nil   // clear any selection
                            appState.selectedTab = 1            // switch to Map tab
                        }
                    ),
                    MenuItem(title: "Find Parking", systemImage: "car.fill", action: { print("Find Parking tapped") }),
                    MenuItem(title: "Find Dining Options", systemImage: "fork.knife", action: { print("Find Dining tapped") })
                ]
            )

            MenuSectionView(
                title: "Popular Destinations",
                items: [
                    MenuItem(title: "Library", systemImage: "book.fill", action: { print("Library tapped") }),
                    MenuItem(title: "Gym", systemImage: "figure.strengthtraining.traditional", action: { print("Gym tapped") })
                ]
            )

            MenuSectionView(
                title: "Recent Locations",
                items: profile.recentLocations.map { loc in
                    MenuItem(title: loc, systemImage: "building", action: { print("Tapped \(loc)") })
                },
                message: "No recent locations yet"
            )

            // FAVORITES SECTION (now driven by profile)
            if profile.favorites.isEmpty {
                MenuSectionView(
                    title: "Favorites",
                    items: nil,
                    message: "No buildings saved"
                )
            } else {
                MenuSectionView(
                    title: "Favorites",
                    items: profile.favorites.map { fav in
                        MenuItem(
                            title: fav,
                            systemImage: "building",
                            action: { print("Tapped \(fav)") }
                        )
                    }
                )
            }
        }
    }
}



/// A reusable button style for menu rows.
///
/// Uses an SF Symbol on the left, the title text, and a subtle rounded border.
struct ActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.red)
                Text(title)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}


/// The main Home screen for Campus Compass.
///
/// Displays:
/// - Header row with app title and profile icon (placeholder).
/// - App name + tagline.
/// - Optional welcome message when a user is logged in.
/// - Search bar and the menu content.
struct HomeView: View {
    var profile: UserProfile

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var buildingStore: BuildingStore
       @State private var searchText = ""
    @State private var userID: String = "Loading..."
    private var filteredBuildings: [CampusBuilding] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        let qLower = q.lowercased()

        return buildingStore.buildings
            .filter { $0.name.localizedCaseInsensitiveContains(q) }
            .sorted { a, b in
                let aName = a.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let bName = b.name.trimmingCharacters(in: .whitespacesAndNewlines)

                let aStarts = aName.lowercased().hasPrefix(qLower)
                let bStarts = bName.lowercased().hasPrefix(qLower)

                // 1) Starts-with matches first
                if aStarts != bStarts { return aStarts && !bStarts }

                // 2) Otherwise alphabetical (stable and predictable)
                return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
            }
            .prefix(6)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Campus Compass")
                    .fontWeight(.bold)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.red)
                }
            }

            Divider()
            Spacer().frame(height: 30)

            //DEBUG TEXT
            Text("User ID: \(userID)")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding()
                    .onAppear {
                        let container = CKContainer.default()

                        container.fetchUserRecordID { recordID, error in
                            if let id = recordID?.recordName {
                                DispatchQueue.main.async {
                                    userID = id
                                }
                            }
                        }
                    }
            Text("Campus Compass")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Navigate Pacific University with ease")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer();
            // 👇 NEW — Welcome Message
            if !profile.name.isEmpty {
                Text("Welcome, \(profile.name)!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)
            }
            SearchBarView(searchText: $searchText)
//            Text("Loaded: \(buildingStore.buildings.count)")
//                .font(.caption)
//                .foregroundColor(.gray)
            // Results drop-down
            if !filteredBuildings.isEmpty {
                VStack(spacing: 8) {
                    ForEach(filteredBuildings) { building in
                        Button {
                            // 1) store selection
                            appState.selectedBuildingID = building.id
                            // 2) jump to map tab
                            appState.selectedTab = 1
                            // 3) optional: clear search
                            searchText = ""
                        } label: {
                            HStack {
                                Image(systemName: "building.2")
                                Text(building.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                )
                .padding(.horizontal)
                .task {
                    if buildingStore.buildings.isEmpty {
                        await buildingStore.fetchBuildings()
                    }
                }
            }
            
            MenuView(profile:profile)
        }
        .padding()
    }
}
