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

                if let offices = location.studentServiceOffices,
                   !offices.isEmpty {

                    InfoRow(
                        title: "Student Services",
                        value: offices.joined(separator: ", ")
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
    let studentServiceOffices: [String]?
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
            hoursOpen: "8AM - 7PM",
            websiteURL: URL(string: "https://www.pacificu.edu"),
            contactInfo: "N/A",
            shortDescription: "Central hub for student services and campus activities."
        ),
        .init(
            name: "Strain Science Center",
            latitude: 45.52180,
            longitude: -123.10723,
            floors: 3,
            studentServiceOffices: ["N/A"],
            accessibilityInfo: "Elevator/ramp info TBD",
            hoursOpen: "7AM - 5PM",
            websiteURL: nil,
            contactInfo: "N/A",
            shortDescription: "Science classrooms and laboratories."
        ),
        .init(
            name: "Aucoin Hall",
            latitude: 45.52142,
            longitude: -123.10982,
            floors: 2,
            studentServiceOffices: ["Academic and Career Advising", "International Student Services"],
            accessibilityInfo: "Elevator/ramp info TBD",
            hoursOpen: "7AM - 5PM",
            websiteURL: nil,
            contactInfo: nil,
            shortDescription: nil
        ),
        .init(
            name: "Tran Library",
            latitude: 45.52144,
            longitude: -123.10860,
            floors: 3, studentServiceOffices: ["Center for Learning and Student Sucess (CLASS)", "24/7 Study Center"],
            accessibilityInfo: "Elevator located just past the help desk",
            hoursOpen: "7:30AM - 7PM",
            websiteURL: URL(string: "https://www.lib.pacificu.edu"),
            contactInfo: "503-352-1400",
            shortDescription: nil
        ),
        .init(
            name: "Murdock Hall",
            latitude: 45.52136,
            longitude: -123.10679,
            floors: 1,
            studentServiceOffices: nil,
            accessibilityInfo: nil,
            hoursOpen: "7AM - 5PM",
            websiteURL: nil,
            contactInfo: nil,
            shortDescription: nil
        ),
        .init(
            name: "McGill Auditorium",
            latitude: 45.52113,
            longitude: -123.10730,
            floors: 1,
            studentServiceOffices: nil,
            accessibilityInfo: nil,
            hoursOpen: "7AM - 5PM",
            websiteURL: nil,
            contactInfo: nil,
            shortDescription: nil
        ),
        .init(
            name: "Berglund Hall",
            latitude: 45.52077,
            longitude: -123.10730,
            floors: 2,
            studentServiceOffices: ["Boxer Maker Space"],
            accessibilityInfo: "Elevator",
            hoursOpen: "7AM - 5PM",
            websiteURL: URL(string:"https://www.pacificu.edu/directory/provost-academic-affairs/berglund-center"),
            contactInfo: "503-352-3185",
            shortDescription: "The Berglund Center at Pacific University is a university-wide innovation center where innovative thinking, entrepreneurship and multidisciplinary team work comes together to launch new products, services and ideas within a vibrant learning community."
        ),
        .init(name: "Cacade Hall",
              latitude: 45.52228,
              longitude: -123.10796,
              floors: 4,
              studentServiceOffices: nil,
              accessibilityInfo: "Elevator",
              hoursOpen: nil,
              websiteURL: URL(string: "https://www.pacificu.edu/about/campuses-locations/forest-grove-campus/residence-halls/cascade-hall"),
              contactInfo: nil,
              shortDescription: "Featuring a sustainable design, Cascade offers students several community lounges, recreation areas, study spaces and community kitchens to launch their college living experience."
             ),
        .init(name: "Price Hall",
              latitude: 45.52186,
              longitude: -123.10797,
              floors: 2,
              studentServiceOffices: nil,
              accessibilityInfo: "Flat surface at main entrence",
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: nil
             ),
        .init(name: "Taylor-Meade Performing Arts Center",
              latitude: 45.52064,
              longitude: -123.10787,
              floors: 2,
              studentServiceOffices: nil,
              accessibilityInfo: nil,
              hoursOpen: "7AM - 5PM",
              websiteURL: URL(string: "https://www.pacificu.edu/about/campuses-locations/forest-grove-campus/taylor-meade-performing-arts-center"),
              contactInfo: nil,
              shortDescription: "Taylor-Meade Performing Arts Center is Pacific University’s nationally recognized performing arts venue and home to the Music Department."
             ),
        .init(name: "Clark Hall",
              latitude: 45.52290,
              longitude: -123.10899,
              floors: 3,
              studentServiceOffices: ["Student Affairs"],
              accessibilityInfo: "Ramp located at front entrance, Elevator across from the help desk",
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: "503-352-2200",
              shortDescription: nil
             ),
        .init(name: "Pacific Bookstore",
              latitude: 45.52179,
              longitude: -123.10869,
              floors: 1,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp outside of the entrance",
              hoursOpen: "10AM - 4PM",
              websiteURL: URL(string: "https://pacific.bncollege.com/?storeId=45058&catalogId=10001&langId=-1"),
              contactInfo: nil,
              shortDescription: "The Pacific University Bookstore, operated by Barnes & Noble, offers textbooks, apparel, gifts and accessories for Pacific University students and friends."
             )
    ]



//    let UCLoc = CLLocationCoordinate2D(latitude: 45.52207, longitude: -123.10894)
//    let Strain = CLLocationCoordinate2D(latitude: 45.52180, longitude: -123.10723)
//    let Aucoin = CLLocationCoordinate2D(latitude: 45.52142, longitude: -123.10982)
//    let Murdock = CLLocationCoordinate2D(latitude: 45.52136, longitude: -123.10679)
//    let MgGill = CLLocationCoordinate2D(latitude: 45.52113, longitude: -123.10730)
//    let Berglund = CLLocationCoordinate2D(latitude: 45.52077, longitude: -123.10730)
//    let Cascade = CLLocationCoordinate2D(latitude: 45.52228, longitude: -123.10796)
//    let Price = CLLocationCoordinate2D(latitude: 45.52186, longitude: -123.10797)
//    let TaylorMeade = CLLocationCoordinate2D(latitude: 45.52064, longitude: -123.10787)
//    let Clark = CLLocationCoordinate2D(latitude: 45.52290, longitude: -123.10899)
//    let Bookstore = CLLocationCoordinate2D(latitude: 45.52179, longitude: -123.10869)
//    let Library = CLLocationCoordinate2D(latitude: 45.52144, longitude: -123.10860)
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
            Marker("Warner Hall", coordinate: Warner)
            Marker("Marsh Hall", coordinate: Marsh)
            Marker("McCormick Hall", coordinate: Mac)
            Marker("Walter Hall", coordinate: Walter)
            Marker("Walter Annex", coordinate: WalterAnnex)
            Marker("Bates House", coordinate: Bates)
            Marker("Carnegie Hall", coordinate: Carnegie)
            Marker("Brown Hall", coordinate: Brown)
            Marker("Drake House", coordinate: Drake)
            Marker("Campus Public Saftey", coordinate: CPS)
            Marker("Admissions Office", coordinate: Admissions)
            Marker("Chapman Hall", coordinate: Chapman)
            Marker("World Language House", coordinate: WLH)
            Marker("Service Center", coordinate: ServiceCenter)
            Marker("Outdoor Pursuits", coordinate: OutdoorPursuits)
            Marker("Old College Hall", coordinate: OldCollege)
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
