//
//  SettingsView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI

/// A reusable toggle component for settings or options lists.
struct ActionToggle: View {
    var title: String
    var systemImage: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                Text(title)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SettingsView: View {
//    var title: String
    @State private var notificationsOn = true
    @State private var darkModeOn = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ActionToggle(title: "Enable Notifications", systemImage: "bell.fill", isOn: $notificationsOn)
                ActionToggle(title: "Dark Mode", systemImage: "moon.fill", isOn: $darkModeOn)
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






#Preview {
    SettingsView()
}




//struct SettingsView: View {
//    var body: some View {
//        Form {
//            Section(header: Text("General")) {
//                Toggle("Example toggle", isOn: .constant(true))
//                Toggle("Example toggle", isOn: .constant(true))
//                NavigationLink("About", destination: Text("About screen"))
//
//
//            }
//            
//        }
//        .navigationTitle("Settings")
//        
//        
//    }
//}

#Preview {
//    SettingsView()
}

