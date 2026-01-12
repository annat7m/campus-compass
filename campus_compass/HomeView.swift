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

/// A simple search input UI used on the Home screen.
///
/// - Note: Currently uses a constant binding, so typing will not persist.
///   Convert to a `@Binding var searchText: String` when wiring up search.
struct SearchBarView: View {
    @State private var searchText: String = ""
    var body: some View {
        TextField("Search...", text: .constant(""))
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
    var session: UserSession

    var body: some View {
        ScrollView {
            MenuSectionView(
                title: "Quick Actions",
                items: [
                    MenuItem(title: "View Campus Map", systemImage: "map", action: { print("Campus Map tapped") }),
                    MenuItem(title: "Find Parking", systemImage: "car.fill", action: { print("Find Parking tapped") }),
                    MenuItem(title: "Find Dining Options", systemImage: "fork.knife", action: { print("Find Dining tapped")})
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
                items: [MenuItem(title: "Strain Science Center", systemImage: "building", action:{print("Strain tapped") })
                       ]
            )
            
            // FAVORITES SECTION
            // Favorites are driven by the user's session state.
            if let user = session.currentUser {
                
                // User is logged in
                if user.favorites.isEmpty {
                    
                    // No favorites saved
                    MenuSectionView(
                        title: "Favorites",
                        items: nil,
                        message: "No buildings saved"
                    )
                    
                } else {
                    
                    // Convert favorites (strings) into MenuItem buttons
                    MenuSectionView(
                        title: "Favorites",
                        items: user.favorites.map { fav in
                            MenuItem(
                                title: fav,
                                systemImage: "building",
                                action: { print("Tapped \(fav)") }
                            )
                        }
                    )
                }
                
            } else {
                
                // No user logged in
                MenuSectionView(
                    title: "Favorites",
                    items: nil,
                    message: "Log in to see your favorite locations!"
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
    var session: UserSession

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

            Text("Campus Compass")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Navigate Pacific University with ease")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer();
            // 👇 NEW — Welcome Message
            if let user = session.currentUser {
                Text("Welcome, \(user.name)!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)
            }
            SearchBarView()
            MenuView(session:session)
        }
        .padding()
    }
}
