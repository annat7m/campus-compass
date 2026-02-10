//
//  MapView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI
import MapKit

struct LocationPreviewSheet: View {
    let location: CampusLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header (like Apple Maps card)
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.title2)
                    .bold()

                if let desc = location.shortDescription {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                openDirections(to: location)
            } label: {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }.buttonStyle(.borderedProminent)
            
            Divider()

            // Details (success criteria)
            VStack(alignment: .leading, spacing: 10) {

                if let floors = location.floors {
                    InfoRow(title: "Floors", value: "\(floors)")
                }

                if !location.studentServiceOffices.isEmpty {
                    InfoRow(
                        title: "Student Services",
                        value: location.studentServiceOffices.joined(separator: ", ")
                    )
                }

                if let accessibility = location.accessibilityInfo {
                    InfoRow(title: "Accessibility", value: accessibility)
                }

                if let hours = location.hoursOpen {
                    InfoRow(title: "Hours", value: hours)
                }

                if let url = location.websiteURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Website")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Link(url.absoluteString, destination: url)
                            .font(.body)
                    }
                }

                if let contact = location.contactInfo {
                    InfoRow(title: "Contact", value: contact)
                }
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}


import MapKit
import CoreLocation

private func openDirections(to location: CampusLocation) {
    let placemark = MKPlacemark(coordinate: location.coordinate)

    let item = MKMapItem(placemark: placemark)
    item.name = location.name

    let options: [String: Any] = [
        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        // or MKLaunchOptionsDirectionsModeDriving
    ]

    item.openInMaps(launchOptions: options)
}



struct CampusLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double

    let floors: Int?
    let studentServiceOffices: [String]
    let accessibilityInfo: String?
    let hoursOpen: String?
    let websiteURL: URL?
    let contactInfo: String?
    let shortDescription: String?
    
    
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
        .init(
            name: "University Center",
            latitude: 45.52207,
            longitude: -123.10894,
            floors: 2,
            studentServiceOffices: ["Front Desk", "Student Life (example)"],
            accessibilityInfo: "Accessible entrances available (placeholder).",
            hoursOpen: "Hours vary (placeholder).",
            websiteURL: URL(string: "https://www.pacificu.edu"),
            contactInfo: "Contact info TBD",
            shortDescription: "Central hub for student services and campus activities."
        ),
        .init(
            name: "Strain Science Center",
            latitude: 45.52180,
            longitude: -123.10723,
            floors: 3,
            studentServiceOffices: ["Office TBD"],
            accessibilityInfo: "Elevator/ramp info TBD",
            hoursOpen: "Hours vary (placeholder).",
            websiteURL: nil,
            contactInfo: "Contact info TBD",
            shortDescription: "Science classrooms and laboratories."
        )
        // add the rest the same way
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
            LocationPreviewSheet(location: location)
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
