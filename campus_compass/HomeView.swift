//
//  HomeView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI

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

struct MenuSectionView: View {
    var title: String
    var items: [MenuItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(items) { item in
                    ActionButton(
                        title: item.title,
                        systemImage: item.systemImage,
                        action: item.action
                    )
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

struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct MenuView: View {
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
            
            MenuSectionView(
                title: "Favorites",
                items: [MenuItem(title: "Strain Science Center", systemImage: "building", action:{print("Strain tapped") }),
                        MenuItem(title: "University Center", systemImage: "building", action:{print("UC tapped") })
                       ]
            )
        }
    }
}



/// A reusable button component for your app's menu-style lists.
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

            // 👇 NEW — Welcome Message
            if let user = session.currentUser {
                Text("Welcome, \(user.name)!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
            }

            Text("Campus Compass")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Navigate Pacific University with ease")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)

            SearchBarView()
            MenuView()
        }
        .padding()
    }
}
