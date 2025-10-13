//
//  HomeView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .imageScale(.large)
                    Text("Hello, world!")
                        .font(.headline)
                    Text("This is Home")
                        .foregroundStyle(.secondary)
                }
                .padding()
    }
}

#Preview {
    HomeView()
}





