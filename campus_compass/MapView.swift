//
//  MapView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI

struct MapView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .imageScale(.large)
            Text("Map goes here")
                .font(.headline)
            Text("Add MapKit later (Map)")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    MapView()
}
