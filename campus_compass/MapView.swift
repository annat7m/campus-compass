//
//  MapView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI
import MapKit

struct CampusLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let latitude: Double
        let longitude: Double

        var coordinate: CLLocationCoordinate2D {
            .init(latitude: latitude, longitude: longitude)
        }
}

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var camera: MapCameraPosition = .automatic
    @State private var hasCenteredOnUser = false   // <- NEW
    @State private var selectedLocation: CampusLocation?
    @Namespace private var mapScope
    
    let campusLocations: [CampusLocation] = [
        .init(name: "University Center",
              description: "Central hub for student services and campus activities.",
              latitude: 45.52207, longitude: -123.10894),

        .init(name: "Strain Science Center",
              description: "Academic building with classrooms and labs.",
              latitude: 45.52180, longitude: -123.10723),
    ]


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
        Map(position: $camera,selection: $selectedLocation, scope: mapScope) {
            UserAnnotation()
            
            ForEach(campusLocations) { location in
                    Marker(location.name, coordinate: location.coordinate)
                        .tag(location)
                }
            
//            Marker("University Center", coordinate: UCLoc)
//            Marker("Strain Science Center", coordinate: Strain)
//            Marker("Aucoin Hall", coordinate: Aucoin)
//            Marker("Murdock Hall", coordinate: Murdock)
//            Marker("McGill Auditorium", coordinate: MgGill)
//            Marker("Berglund Hall", coordinate: Berglund)
//            Marker("Cascade Hall", coordinate: Cascade)
//            Marker("Price Hall", coordinate: Price)
//            Marker("Taylor-Meade Performing Arts", coordinate: TaylorMeade)
//            Marker("Clark Hall", coordinate: Clark)
//            Marker("Pacific Bookstore", coordinate: Bookstore)
//            Marker("Tran Library", coordinate: Library)
//            Marker("Warner Hall", coordinate: Warner)
//            Marker("Marsh Hall", coordinate: Marsh)
//            Marker("McCormick Hall", coordinate: Mac)
//            Marker("Walter Hall", coordinate: Walter)
//            Marker("Walter Annex", coordinate: WalterAnnex)
//            Marker("Bates House", coordinate: Bates)
//            Marker("Carnegie Hall", coordinate: Carnegie)
//            Marker("Brown Hall", coordinate: Brown)
//            Marker("Drake House", coordinate: Drake)
//            Marker("Campus Public Saftey", coordinate: CPS)
//            Marker("Admissions Office", coordinate: Admissions)
//            Marker("Chapman Hall", coordinate: Chapman)
//            Marker("World Language House", coordinate: WLH)
//            Marker("Service Center", coordinate: ServiceCenter)
//            Marker("Outdoor Pursuits", coordinate: OutdoorPursuits)
//            Marker("Old College Hall", coordinate: OldCollege)
        }.onAppear {
            locationManager.requestPermissionAndStart()
        }.mapControls{
            MapUserLocationButton(scope: mapScope)
            MapCompass(scope: mapScope)
            MapScaleView(scope: mapScope)
        }.sheet(item: $selectedLocation) { location in
            VStack(alignment: .leading, spacing: 12) {
                Text(location.name).font(.title2).bold()
                Text(location.description)
                Spacer()
            }
            .padding()
            .presentationDetents([.medium])
        }
//        .onReceive(locationManager.$location) { location in
//            guard let location, !hasCenteredOnUser else { return }
//
//            hasCenteredOnUser = true   // only do this once
//            camera = .region(
//                MKCoordinateRegion(
//                    center: location.coordinate,
//                    span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                )
//            )
//        }.ignoresSafeArea()
    }
}
