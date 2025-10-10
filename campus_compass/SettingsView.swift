//
//  SettingsView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Example toggle", isOn: .constant(true))
                NavigationLink("About", destination: Text("About screen"))
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
