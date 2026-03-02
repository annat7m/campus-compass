//
//  WelcomeSplashView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 3/2/26.
//

import SwiftUI

struct AnimatedLettersView: View {
    let text: String
    let font: Font
    let letterDelay: UInt64
    let animation: Animation

    @State private var revealedCount = 0

    init(
        text: String,
        font: Font,
        letterDelay: UInt64 = 70_000_000,
        animation: Animation = .easeOut(duration: 0.22)
    ) {
        self.text = text
        self.font = font
        self.letterDelay = letterDelay
        self.animation = animation
    }

    var body: some View {
        let letters = Array(text)

        HStack(spacing: 0) {
            ForEach(letters.indices, id: \.self) { index in
                Text(String(letters[index]))
                    .opacity(index < revealedCount ? 1 : 0)
                    .offset(y: index < revealedCount ? 0 : 6)
            }
        }
        .font(font)
        .onAppear {
            revealedCount = 0
            Task { @MainActor in
                for index in letters.indices {
                    let delay = letters[index] == " " ? letterDelay / 3 : letterDelay
                    try? await Task.sleep(nanoseconds: delay)
                    withAnimation(animation) {
                        revealedCount = index + 1
                    }
                }
            }
        }
    }
}

struct WelcomeSplashView: View {
    @State private var showSubtitle = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {
                AnimatedLettersView(
                    text: "Campus Compass",
                    font: .custom("Avenir Next", size: 30).weight(.bold)
                )
                .foregroundColor(.primary)

                Text("Pacific University")
                    .font(.custom("Avenir Next", size: 16).weight(.semibold))
                    .foregroundColor(.secondary)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 6)
            }
        }
        .onAppear {
            showSubtitle = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                withAnimation(.easeOut(duration: 0.35)) {
                    showSubtitle = true
                }
            }
        }
    }
}

#Preview {
    WelcomeSplashView()
}
