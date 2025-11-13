//
//  MapView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var camera: MapCameraPosition = .automatic
    @State private var hasCenteredOnUser = false   // <- NEW

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
        }
        .onReceive(locationManager.$location) { location in
            guard let location, !hasCenteredOnUser else { return }

            hasCenteredOnUser = true   // only do this once

            camera = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
        .ignoresSafeArea()
    }
}
