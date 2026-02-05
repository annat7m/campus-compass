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
    
    let UCLoc = CLLocationCoordinate2D(latitude: 45.52207, longitude: -123.10894)
    let Strain = CLLocationCoordinate2D(latitude: 45.52180, longitude: -123.10723)
    let Aucoin = CLLocationCoordinate2D(latitude: 45.52142, longitude: -123.10982)
    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            
            Marker("University Center", coordinate: UCLoc)
            Marker("Strain Science Center", coordinate: Strain)
            Marker("Aucoin Hall", coordinate: Aucoin)
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
