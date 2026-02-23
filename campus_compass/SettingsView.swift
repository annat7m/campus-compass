//
//  SettingsView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//



import SwiftUI
import SwiftData
import CloudKit

    struct SettingsHeaderView: View {
        var title: String
        var onBack: (() -> Void)?
        var onProfileTap: (() -> Void)?
        
        var body: some View {
            
            HStack{
                Text("Campus Compass")
                    .fontWeight(.bold)
                
                Spacer()
                
                // Profile Icon
                Button(action: { onProfileTap?() }) {
                    Image(systemName: "person.circle.fill") // SF Symbol
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.red)
                    
                    
                }
            }
            Divider()
            
            HStack {
                
                
                // Back Button
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Title
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.leading, 8)
                
                
                Spacer()
                
            }
            
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            
            
            
        }
    }
    
    
    
    
    // MARK: - Model
    /// Represents one toggle item inside a section (e.g. “Dark Mode” or “Enable Notifications”)
    
    /// Represents a single toggle setting item.
    struct ToggleItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let systemImage: String
        var isOn: Bool
    }
    
    
    struct ToggleRowView: View {
        @Binding var item: ToggleItem
        
        var body: some View {
            Toggle(isOn: $item.isOn) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.systemImage)
                        .foregroundColor(.red)
                        .frame(width: 22)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .red))
            .padding(.vertical, 6)
        }
    }
    
    
    
    struct ToggleSectionView: View {
        let title: String
        @Binding var items: [ToggleItem]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 10) {
                    ForEach($items) { $item in
                        ToggleRowView(item: $item)
                        
                        // Divider between items
                        if item.id != items.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    

/** What gets rendered to the screen*/

struct SettingsView: View {

    @Binding var selectedTab: Int
    var profile: UserProfile
    @Binding var settingsPath: NavigationPath

    @Environment(\.modelContext) private var modelContext

    @State private var iCloudStatus: CKAccountStatus? = nil

    // Keep your toggles, but we'll wire Accessibility Mode to profile.prefersAccessibility
    @State private var accessibilityToggles = [
        ToggleItem(title: "Accessibility Mode", subtitle: "Show only accessible routes and highlight accessibility features", systemImage: "figure.roll", isOn: false),
        ToggleItem(title: "Avoid Stairs", subtitle: "Prefer routes with ramps and elevators", systemImage: "stairs", isOn: false),
        ToggleItem(title: "Voice Navigation", subtitle: "Enable spoken turn-by-turn directions", systemImage: "speaker.wave.2.fill", isOn: true),
        ToggleItem(title: "Large Text", subtitle: "Increase text size for better readability", systemImage: "textformat.size", isOn: false)
    ]

    @State private var notificationToggles = [
        ToggleItem(title: "Navigation Updates", subtitle: "Get notified of route changes or delays", systemImage: "bell.fill", isOn: true)
    ]

    @State private var navigationPreferences = [
        ToggleItem(title: "Scenic Route", subtitle: "Take the prettiest path to your destination", systemImage: "landscape", isOn: false),
        ToggleItem(title: "Quiet Path", subtitle: "A calm way to your destination", systemImage: "range.fill", isOn: false)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: - Profile Section (replaces Login/Signup)
                profileSection

                // MARK: - iCloud status (optional but helpful)
                if let iCloudStatus {
                    iCloudStatusSection(status: iCloudStatus)
                }

                // MARK: - SETTINGS SECTIONS
                ToggleSectionView(title: "Accessibility", items: $accessibilityToggles)
                ToggleSectionView(title: "Notifications", items: $notificationToggles)
                ToggleSectionView(title: "Preferences", items: $navigationPreferences)

            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Initialize UI toggle state from model
            accessibilityToggles[0].isOn = profile.prefersAccessibility
        }
        .onChange(of: accessibilityToggles[0].isOn) { _, newValue in
            // Persist change into SwiftData model
            profile.prefersAccessibility = newValue
            try? modelContext.save()
        }
        .task {
            await loadICloudStatus()
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)

            TextField("Your name", text: Binding(
                get: { profile.name },
                set: { newValue in
                    profile.name = newValue
                    try? modelContext.save()
                }
            ))
            .textFieldStyle(.roundedBorder)

            Text("This profile syncs across your devices when iCloud is enabled.")
                .font(.footnote)
                .foregroundColor(.secondary)

        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal)
    }

    private func iCloudStatusSection(status: CKAccountStatus) -> some View {
        let message: String
        switch status {
        case .available:
            message = "iCloud is available. Your profile should sync across devices."
        case .noAccount:
            message = "No iCloud account is signed in. Your data will stay on this device."
        case .restricted:
            message = "iCloud is restricted on this device."
        case .couldNotDetermine:
            message = "Could not determine iCloud status."
        @unknown default:
            message = "Unknown iCloud status."
        }

        return Text(message)
            .font(.footnote)
            .foregroundColor(status == .available ? .secondary : .red)
            .padding(.horizontal)
    }

    private func loadICloudStatus() async {
        let container = CKContainer.default()
        do {
            let status: CKAccountStatus = try await withCheckedThrowingContinuation {
                (cont: CheckedContinuation<CKAccountStatus, Error>) in
                container.accountStatus { status, error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume(returning: status) }
                }
            }
            iCloudStatus = status
        } catch {
            // If this fails, don't crash; just leave status nil
            iCloudStatus = nil
            print("Failed to get iCloud status: \(error)")
        }
    }
}
    
    
