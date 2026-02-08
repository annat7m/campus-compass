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
    let Murdock = CLLocationCoordinate2D(latitude: 45.52136, longitude: -123.10679)
    let MgGill = CLLocationCoordinate2D(latitude: 45.52113, longitude: -123.10730)
    let Berglund = CLLocationCoordinate2D(latitude: 45.52077, longitude: -123.10730)
    let Cascade = CLLocationCoordinate2D(latitude: 45.52228, longitude: -123.10796)
    let Price = CLLocationCoordinate2D(latitude: 45.52186, longitude: -123.10797)
    let TaylorMeade = CLLocationCoordinate2D(latitude: 45.52064, longitude: -123.10787)
    let Clark = CLLocationCoordinate2D(latitude: 45.52290, longitude: -123.10899)
    let Bookstore = CLLocationCoordinate2D(latitude: 45.52179, longitude: -123.10869)
    let Library = CLLocationCoordinate2D(latitude: 45.52144, longitude: -123.10860)
    let Warner = CLLocationCoordinate2D(latitude: 45.52002, longitude: -123.10942)
    let Marsh = CLLocationCoordinate2D(latitude: 45.52095, longitude: -123.10946)
    let Mac = CLLocationCoordinate2D(latitude: 45.52283, longitude: -123.11012)
    let Walter = CLLocationCoordinate2D(latitude: 45.52218, longitude: -123.10998)
    let WalterAnnex = CLLocationCoordinate2D(latitude: 45.52199, longitude: -123.11030)
    let Bates = CLLocationCoordinate2D(latitude: 45.52192, longitude: -123.11058)
    let Carnegie = CLLocationCoordinate2D(latitude: 45.52021, longitude: -123.11034)
    let Brown = CLLocationCoordinate2D(latitude: 45.51990, longitude: -123.11026)
    let Drake = CLLocationCoordinate2D(latitude: 45.52165, longitude: -123.11134)
    
    
    
    
    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            
            Marker("University Center", coordinate: UCLoc)
            Marker("Strain Science Center", coordinate: Strain)
            Marker("Aucoin Hall", coordinate: Aucoin)
            Marker("Murdock Hall", coordinate: Murdock)
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
