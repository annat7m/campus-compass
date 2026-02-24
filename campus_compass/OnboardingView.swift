//
//  OnboardingView.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 2/23/26.
//

import SwiftUI

struct OnboardingView: View {
    var onCreate: (String) -> Void

    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to Campus Compass")
                .font(.title2)
                .bold()

            Text("Set up your profile to sync across devices with iCloud.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("Create Profile") {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onCreate(trimmed)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding()
    }
}
