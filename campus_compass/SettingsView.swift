//
//  SettingsView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//



import SwiftUI


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
        var session: UserSession
        @Binding var settingsPath: NavigationPath
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
                        
                        // MARK: - AUTH SECTION
                        if session.currentUser == nil {
                            
                            // User is logged out → show Log In + Sign Up
                            VStack(spacing: 0) {
                                
                                NavigationLink {
                                    LoginView(selectedTab: $selectedTab, session: session, settingsPath: $settingsPath)
                                } label: {
                                    HStack {
                                        Image(systemName: "person.circle")
                                            .foregroundColor(.red)
                                        Text("Log In")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                }
                                
                                Divider()
                                
                                NavigationLink {
                                    SignUpView(selectedTab: $selectedTab, session: session, settingsPath: $settingsPath)
                                } label: {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .foregroundColor(.red)
                                        Text("Sign Up")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal)
                            
                        } else {
                            
                            // User IS logged in → show Log Out only
                            VStack(spacing: 0) {
                                Button(role: .destructive) {
                                    logout()
                                } label: {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundColor(.red)
                                        Text("Log Out")
                                            .foregroundColor(.red)
                                            .font(.headline)
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal)
                        }

                        // MARK: - SETTINGS SECTIONS
                        ToggleSectionView(title: "Accessibility", items: $accessibilityToggles)
                        ToggleSectionView(title: "Notifications", items: $notificationToggles)
                        ToggleSectionView(title: "Preferences", items: $navigationPreferences)
                        
                    }
                    .padding(.top)
                }
                .background(Color(.systemGroupedBackground))
            }
        
        private func logout() {
            session.currentUser = nil      // Clears logged-in user
            selectedTab = 2                // Stay on Settings tab (optional)
            print("User logged out")
        }

    }
    
    

    
    
    
    

