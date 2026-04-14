//
//  HomeView.swift
//  Campus Compass
//
//  Purpose:
//  Modernized home screen layout inspired by contemporary travel apps.
//  Keeps existing data/actions while upgrading the presentation.
//

import SwiftUI
import CloudKit

private enum HomePalette {
    static let ink = Color(red: 0.14, green: 0.15, blue: 0.17)
    static let fog = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let mist = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let accent = Color(red: 0.88, green: 0.20, blue: 0.25)

    static let teal = [
        Color(red: 0.26, green: 0.67, blue: 0.78),
        Color(red: 0.12, green: 0.45, blue: 0.62)
    ]

    static let sunset = [
        Color(red: 0.96, green: 0.66, blue: 0.37),
        Color(red: 0.88, green: 0.32, blue: 0.36)
    ]

    static let moss = [
        Color(red: 0.45, green: 0.72, blue: 0.53),
        Color(red: 0.20, green: 0.50, blue: 0.36)
    ]

    static let slate = [
        Color(red: 0.22, green: 0.24, blue: 0.28),
        Color(red: 0.10, green: 0.11, blue: 0.13)
    ]
}

struct HomeTheme {
    let scheme: ColorScheme

    var ink: Color { scheme == .dark ? .white : HomePalette.ink }
    var mutedText: Color { scheme == .dark ? .white.opacity(0.7) : .secondary }
    var surface: Color { Color(.systemBackground) }
    var surfaceElevated: Color { scheme == .dark ? Color(.secondarySystemBackground) : .white }
    var outline: Color { scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06) }
    var shadowSoft: Color { Color.black.opacity(scheme == .dark ? 0.32 : 0.06) }
    var shadowStrong: Color { Color.black.opacity(scheme == .dark ? 0.45 : 0.14) }

    var backgroundGradient: [Color] {
        scheme == .dark
            ? [Color(red: 0.07, green: 0.08, blue: 0.10), Color(red: 0.12, green: 0.13, blue: 0.16)]
            : [HomePalette.fog, HomePalette.mist]
    }

    var blobBlue: Color { HomePalette.teal[0].opacity(scheme == .dark ? 0.22 : 0.20) }
    var blobSunset: Color { HomePalette.sunset[0].opacity(scheme == .dark ? 0.20 : 0.18) }

    var chipBackground: Color { scheme == .dark ? Color.white.opacity(0.12) : .white }
    var chipSelectedBackground: Color { scheme == .dark ? .white : HomePalette.ink }
    var chipText: Color { scheme == .dark ? .white : HomePalette.ink }
    var chipSelectedText: Color { scheme == .dark ? HomePalette.ink : .white }

    var controlBackground: Color { scheme == .dark ? .white : HomePalette.ink }
    var controlForeground: Color { scheme == .dark ? HomePalette.ink : .white }

    var avatarGradient: [Color] {
        scheme == .dark
            ? [Color.white.opacity(0.35), Color.white.opacity(0.18)]
            : HomePalette.slate
    }

    var avatarIcon: Color { scheme == .dark ? HomePalette.ink : Color.white.opacity(0.9) }

    var cardOverlay: LinearGradient {
        LinearGradient(
            colors: [Color.black.opacity(0.0), Color.black.opacity(scheme == .dark ? 0.35 : 0.25)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// A lightweight model representing a tappable item on the Home screen.
struct MenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void

    init(id: String = UUID().uuidString, title: String, systemImage: String, action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}

enum HomeSection: String, CaseIterable, Identifiable {
    case quickActions
    case popular
    case recent
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickActions: return "Quick Actions"
        case .popular: return "Popular Destinations"
        case .recent: return "Recent Locations"
        case .favorites: return "Favorites"
        }
    }

    var chipTitle: String {
        switch self {
        case .quickActions: return "Actions"
        case .popular: return "Popular"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        }
    }

    var anchor: String {
        "home-section-\(rawValue)"
    }

    var gradient: [Color] {
        switch self {
        case .popular: return HomePalette.teal
        case .recent: return HomePalette.sunset
        case .favorites: return HomePalette.moss
        case .quickActions: return HomePalette.slate
        }
    }
}

struct HomeBackgroundView: View {
    var theme: HomeTheme

    var body: some View {
        LinearGradient(
            colors: theme.backgroundGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Circle()
                .fill(theme.blobBlue)
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: -140, y: -160)
        )
        .overlay(
            Circle()
                .fill(theme.blobSunset)
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: 160, y: 240)
        )
        .ignoresSafeArea()
    }
}

struct HomeHeaderView: View {
    var userName: String?
    var theme: HomeTheme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(userName.map { "Hello, \($0)" } ?? "Hello")
                    .font(.custom("Avenir Next", size: 28).weight(.bold))
                    .foregroundColor(theme.ink)

                Text("Welcome to Campus Compass")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundColor(theme.mutedText)
            }

            Spacer()

            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: theme.avatarGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(theme.avatarIcon)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.surfaceElevated.opacity(theme.scheme == .dark ? 0.9 : 0.95))
                .shadow(color: theme.shadowSoft, radius: 14, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.outline, lineWidth: 1)
        )
    }
}

struct SearchBarView: View {
    var theme: HomeTheme
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var buildingStore: BuildingStore
    @EnvironmentObject private var roomSearchStore: RoomSearchStore

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
                if aStarts != bStarts { return aStarts && !bStarts }
                return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
            }
            .prefix(3)
            .map { $0 }
    }

    private var filteredRooms: [RoomSearchResult] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let qLower = q.lowercased()
        return roomSearchStore.rooms
            .filter { $0.name.localizedCaseInsensitiveContains(q) }
            .sorted { a, b in
                let aStarts = a.name.lowercased().hasPrefix(qLower)
                let bStarts = b.name.lowercased().hasPrefix(qLower)
                if aStarts != bStarts { return aStarts && !bStarts }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.mutedText)
                TextField("Search buildings & rooms...", text: $searchText)
                    .font(.custom("Avenir Next", size: 15))
                    .focused($isFocused)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.mutedText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surfaceElevated)
                    .shadow(color: theme.shadowSoft, radius: 10, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.outline, lineWidth: 1)
            )
            .frame(maxWidth: .infinity)

            if !filteredBuildings.isEmpty || !filteredRooms.isEmpty {
                VStack(spacing: 0) {
                    ForEach(filteredBuildings) { building in
                        Button {
                            appState.selectedBuildingID = building.id
                            appState.selectedTab = 1
                            searchText = ""
                            isFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "building.2")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(building.name)
                                        .font(.custom("Avenir Next", size: 15))
                                        .foregroundColor(.primary)
                                    Text("Building")
                                        .font(.custom("Avenir Next", size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }

                    ForEach(filteredRooms) { room in
                        Button {
                            appState.selectedRoom = room
                            appState.selectedTab = 1
                            searchText = ""
                            isFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "door.right.hand.open")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name)
                                        .font(.custom("Avenir Next", size: 15))
                                        .foregroundColor(.primary)
                                    Text(room.buildingName)
                                        .font(.custom("Avenir Next", size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                            }
                            .contentShape(Rectangle())
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
            }
        }
    }
}

struct SectionChipsView: View {
    var sections: [HomeSection]
    @Binding var selected: HomeSection
    var onSelect: (HomeSection) -> Void
    var theme: HomeTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sections) { section in
                    Button(action: {
                        selected = section
                        onSelect(section)
                    }) {
                        Text(section.chipTitle)
                            .font(.custom("Avenir Next", size: 14).weight(.semibold))
                            .foregroundColor(selected == section ? theme.chipSelectedText : theme.chipText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selected == section ? theme.chipSelectedBackground : theme.chipBackground)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(theme.outline, lineWidth: selected == section ? 0 : 1)
                            )
                            .shadow(color: theme.shadowSoft, radius: selected == section ? 8 : 4, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct SectionHeaderView: View {
    var title: String
    var subtitle: String? = nil
    var theme: HomeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next", size: 20).weight(.bold))
                .foregroundColor(theme.ink)

            if let subtitle {
                Text(subtitle)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundColor(theme.mutedText)
            }
        }
    }
}

struct QuickActionCard: View {
    var item: MenuItem
    var gradient: [Color]
    var theme: HomeTheme

    private var cardGradient: [Color] {
        gradient.map { $0.opacity(theme.scheme == .dark ? 0.22 : 0.14) }
    }

    private var iconGradient: [Color] {
        gradient.map { $0.opacity(theme.scheme == .dark ? 0.95 : 0.85) }
    }

    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )

                Text(item.title)
                    .font(.custom("Avenir Next", size: 15).weight(.semibold))
                    .foregroundColor(theme.ink)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: cardGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.outline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionsRow: View {
    var items: [MenuItem]
    var theme: HomeTheme

    private let gradients: [[Color]] = [
        HomePalette.teal,
        HomePalette.sunset,
        HomePalette.moss
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: HomeSection.quickActions.title,
                subtitle: "Jump into what you need fast",
                theme: theme
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        QuickActionCard(
                            item: item,
                            gradient: gradients[index % gradients.count],
                            theme: theme
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct LocationCardView: View {
    var item: MenuItem
    var category: String
    var gradient: [Color]
    var size: CGSize
    var theme: HomeTheme

    var body: some View {
        Button(action: item.action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(theme.cardOverlay)
                    )

                Image(systemName: item.systemImage)
                    .font(.system(size: 70, weight: .bold))
                    .foregroundColor(.white.opacity(0.22))
                    .offset(x: size.width * 0.28, y: -size.height * 0.15)

                VStack(alignment: .leading, spacing: 8) {
                    Text(category.uppercased())
                        .font(.custom("Avenir Next", size: 11).weight(.bold))
                        .foregroundColor(.white.opacity(0.85))

                    Text(item.title)
                        .font(.custom("Avenir Next", size: 22).weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack {
                        Text("See details")
                            .font(.custom("Avenir Next", size: 13).weight(.semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                }
                .padding(18)
            }
            .frame(width: size.width, height: size.height)
        }
        .buttonStyle(.plain)
    }
}

struct LocationCardsRow: View {
    var items: [MenuItem]
    var gradient: [Color]
    var cardSize: CGSize
    var category: String
    var theme: HomeTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(items) { item in
                    LocationCardView(
                        item: item,
                        category: category,
                        gradient: gradient,
                        size: cardSize,
                        theme: theme
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct SectionCarouselView: View {
    var title: String
    var subtitle: String? = nil
    var items: [MenuItem]
    var gradient: [Color]
    var cardSize: CGSize
    var theme: HomeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title, subtitle: subtitle, theme: theme)
            LocationCardsRow(items: items, gradient: gradient, cardSize: cardSize, category: title, theme: theme)
        }
    }
}

struct EmptyStateCardView: View {
    var title: String
    var message: String
    var theme: HomeTheme

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.ink.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.ink)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next", size: 16).weight(.semibold))
                    .foregroundColor(theme.ink)

                Text(message)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundColor(theme.mutedText)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surfaceElevated)
                .shadow(color: theme.shadowSoft, radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.outline, lineWidth: 1)
        )
    }
}

struct HomeView: View {
    var profile: UserProfile

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: HomeSection = .popular
    @State private var animateIn = false

    private var theme: HomeTheme { HomeTheme(scheme: colorScheme) }

    private let quickActions: [MenuItem] = [
        MenuItem(id: "quick-map", title: "View Campus Map", systemImage: "map", action: { print("Campus Map tapped") }),
        MenuItem(id: "quick-parking", title: "Find Parking", systemImage: "car.fill", action: { print("Find Parking tapped") }),
        MenuItem(id: "quick-dining", title: "Find Dining Options", systemImage: "fork.knife", action: { print("Find Dining tapped") })
    ]

    private let popularDestinations: [MenuItem] = [
        MenuItem(id: "popular-library", title: "Library", systemImage: "book.fill", action: { print("Library tapped") }),
        MenuItem(id: "popular-gym", title: "Gym", systemImage: "figure.strengthtraining.traditional", action: { print("Gym tapped") })
    ]

    private let recentLocations: [MenuItem] = [
        MenuItem(id: "recent-strain", title: "Strain Science Center", systemImage: "building", action: { print("Strain tapped") })
    ]

    private var favoriteItems: [MenuItem] {
        return profile.favorites.map { favorite in
            MenuItem(
                id: "favorite-\(favorite)",
                title: favorite,
                systemImage: "building",
                action: { print("Tapped \(favorite)") }
            )
        }
    }

    var body: some View {
        ZStack {
            HomeBackgroundView(theme: theme)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        HomeHeaderView(userName: profile.name, theme: theme)
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 16)

                        SearchBarView(theme: theme)
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 16)

                        QuickActionsRow(items: quickActions, theme: theme)
                            .id(HomeSection.quickActions.anchor)
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 16)

                        SectionCarouselView(
                            title: HomeSection.popular.title,
                            subtitle: "Student favorites across campus",
                            items: popularDestinations,
                            gradient: HomeSection.popular.gradient,
                            cardSize: CGSize(width: 260, height: 190),
                            theme: theme
                        )
                        .id(HomeSection.popular.anchor)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 16)

                        SectionCarouselView(
                            title: HomeSection.recent.title,
                            subtitle: "Pick up where you left off",
                            items: recentLocations,
                            gradient: HomeSection.recent.gradient,
                            cardSize: CGSize(width: 240, height: 176),
                            theme: theme
                        )
                        .id(HomeSection.recent.anchor)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 16)

                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeaderView(
                                title: HomeSection.favorites.title,
                                subtitle: "Your saved places",
                                theme: theme
                            )

                            if favoriteItems.isEmpty {
                                EmptyStateCardView(
                                    title: "No buildings saved",
                                    message: "Tap the heart on a location to add it here.",
                                    theme: theme
                                )
                            } else {
                                LocationCardsRow(
                                    items: favoriteItems,
                                    gradient: HomeSection.favorites.gradient,
                                    cardSize: CGSize(width: 240, height: 176),
                                    category: HomeSection.favorites.title,
                                    theme: theme
                                )
                            }
                        }
                        .id(HomeSection.favorites.anchor)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
    }
}
