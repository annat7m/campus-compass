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
    let CPS = CLLocationCoordinate2D(latitude: 45.52180, longitude: -123.11129)
    let Admissions = CLLocationCoordinate2DMake(45.52243, -123.11142)
    let Chapman = CLLocationCoordinate2DMake(45.52262, -123.11151)
    let WLH = CLLocationCoordinate2DMake(45.52291, -123.11127)
    let ServiceCenter = CLLocationCoordinate2DMake(45.52114, -123.11117)
    let OutdoorPursuits = CLLocationCoordinate2DMake(45.52110, -123.11129)
    let OldCollege = CLLocationCoordinate2DMake(45.52040, -123.11076)
    
    
    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            
            Marker("University Center", coordinate: UCLoc)
            Marker("Strain Science Center", coordinate: Strain)
            Marker("Aucoin Hall", coordinate: Aucoin)
            Marker("Murdock Hall", coordinate: Murdock)
            Marker("McGill", coordinate: MgGill)
            Marker("Berglund", coordinate: Berglund)
            Marker("Cascade", coordinate: Cascade)
            Marker("Price", coordinate: Price)
            Marker("Taylor-Meade", coordinate: TaylorMeade)
            Marker("Clark", coordinate: Clark)
            Marker("Bookstore", coordinate: Bookstore)
            Marker("Library", coordinate: Library)
            Marker("Warner", coordinate: Warner)
            Marker("Marsh", coordinate: Marsh)
            Marker("Mac", coordinate: Mac)
            Marker("Walter", coordinate: Walter)
            Marker("Walter Annex", coordinate: WalterAnnex)
            Marker("Bates", coordinate: Bates)
            Marker("Carnegie", coordinate: Carnegie)
            Marker("Brown", coordinate: Brown)
            Marker("Drake", coordinate: Drake)
            Marker("CPS", coordinate: CPS)
            Marker("Admissions", coordinate: Admissions)
            Marker("Chapman", coordinate: Chapman)
            Marker("WLH", coordinate: WLH)
            Marker("Service Center", coordinate: ServiceCenter)
            Marker("Outdoor Pursuits", coordinate: OutdoorPursuits)
            Marker("Old College", coordinate: OldCollege)
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
