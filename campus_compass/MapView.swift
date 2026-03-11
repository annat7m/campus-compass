//
//  MapView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct LocationPreviewSheet: View {
    let location: CampusLocation
    let onDirectionsTapped: (CampusLocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                onDirectionsTapped(location)
            } label: {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }
            .buttonStyle(.borderedProminent)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                if let floors = location.floors {
                    InfoRow(title: "Floors", value: "\(floors)")
                }

                if let offices = location.studentServiceOffices, !offices.isEmpty {
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

struct NavigationStepsView: View {
    let steps: [MKRoute.Step]
    let currentStepIndex: Int
    let destinationName: String

    var body: some View {
        NavigationStack {
            List {
                Section("Destination") {
                    Text(destinationName)
                }

                Section("Directions") {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: index == currentStepIndex ? "location.fill" : "arrow.turn.down.right")
                                .foregroundStyle(index == currentStepIndex ? .blue : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.instructions)
                                    .font(.body)

                                Text(stepDistanceText(step.distance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Turn-by-Turn")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func stepDistanceText(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return "\(Int(meters)) m"
        }
    }
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
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var buildingStore: BuildingStore
    
    
    @State private var showDirectionsList = false
    @State private var activeRoute: MKRoute?
    @State private var routeSteps: [MKRoute.Step] = []
    @State private var currentStepIndex: Int = 0
    @State private var isNavigating = false
    @State private var isCalculatingRoute = false
    @State private var navigationError: String?
    @State private var navigationDestination: CampusLocation?
    
    @StateObject private var locationManager = LocationManager()
    @State private var camera: MapCameraPosition = .automatic
    @State private var hasCenteredOnUser = false   // <- NEW
    @State private var selectedLocation: CampusLocation?
    @Namespace private var mapScope
    
    private var currentStep: MKRoute.Step? {
        guard routeSteps.indices.contains(currentStepIndex) else { return nil }
        return routeSteps[currentStepIndex]
    }
    
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
              websiteURL: URL(string: "https://www.pacificu.edu/directory/student-affairs/conferences-events"),
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
             ),
        .init(name: "Warner Hall",
              latitude: 45.52002,
              longitude: -123.10942,
              floors: 2,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp access at the entrance",
              hoursOpen: "7AM - 5PM",
              websiteURL: URL(string: "https://www.pacificu.edu/calendar-by-tag?tid=2278"),
              contactInfo: nil,
              shortDescription: "Warner Hall is home to the Theatre & Dance Department at Pacific and houses the small Tom Miles Theatre and a dance studio. "
             ),
        .init(name: "Marsh Hall",
              latitude: 45.52095,
              longitude: -123.10946,
              floors: 4,
              studentServiceOffices: ["Student Accounts", "Office of Financial Aid"],
              accessibilityInfo: "Ramp available at main enterance",
              hoursOpen: "7AM - 5PM",
              websiteURL: URL(string: "https://www.pacificu.edu/directory/student-affairs/office-financial-aid"),
              contactInfo: "503-352-2857",
              shortDescription: "Built in 1895, Marsh Hall was named for Pacific's first president, Sidney Harper Marsh. It was gutted by a fire in 1975 but carefully restored to be home to administrative offices, faculty offices and classrooms today."
             ),
        .init(name: "McCormick Hall",
              latitude: 45.52283,
              longitude: -123.11012,
              floors: 3,
              studentServiceOffices: nil,
              accessibilityInfo: "Accessability Lift on the left entrance",
              hoursOpen: nil,
              websiteURL: URL(string: "https://www.pacificu.edu/about/campuses-locations/forest-grove-campus/residence-halls/mccormick-hall"),
              contactInfo: nil,
              shortDescription: "McCormick Hall is a traditional-style residence hall with single, double and quad rooms, along with social and study areas, a community kitchen and laundry facilities. Fondly known as “Mac” and bearing a storied history among Pacific alumni, McCormick Hall is home to many first and second-year students."
             ),
        .init(name: "Walter Hall",
              latitude: 45.52218,
              longitude: -123.10998,
              floors: 4,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp located at main entrance",
              hoursOpen: nil,
              websiteURL: URL(string: "https://www.pacificu.edu/about/campuses-locations/forest-grove-campus/residence-halls/walter-hall"),
              contactInfo: nil,
              shortDescription: "Primarily housing first-year students, Walter is a great place to meet people! It's known for having lots of open doors and community events for students to get to know each other."
             ),
        .init(name: "Walter Annex",
              latitude: 45.52199,
              longitude: -123.11030,
              floors: 1,
              studentServiceOffices: nil,
              accessibilityInfo: nil,
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "A small building behind the Walter residence hall containing individual classrooms"
             ),
        .init(name: "Bates House",
              latitude: 45.52192,
              longitude: -123.11058,
              floors: 2,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp access available",
              hoursOpen: nil,
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "Bates House is home to the Pacific University staff and faculty offices."
             ),
        .init(name: "Carnegie Hall",
              latitude: 45.52021,
              longitude: -123.11034,
              floors: 3,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp access available",
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "Built in 1912, Carnegie Hall was Pacific's original campus library - the only academic library west of the Mississippi funded by the Carnegie Foundation. Today, Carnegie is home to classrooms and faculty offices for the university."
             ),
        .init(name: "Brown Hall",
              latitude: 45.51990,
              longitude: -123.11026,
              floors: 1,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp access available for the main art studio",
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "Brown Hall is home to the Art Department at Pacific"
             ),
        .init(name: "Drake House",
              latitude: 45.52165,
              longitude: -123.11134,
              floors: 2,
              studentServiceOffices: ["University of Philosophy"],
              accessibilityInfo: "Ramp access available",
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "Drake House is a cozy home for the faculty offices for members of the Pacific University Philosophy"
             ),
        .init(name: "Campus Public Safety (CPS)",
              latitude: 45.52180,
              longitude: -123.11129,
              floors: 1,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp access available",
              hoursOpen: "24/7",
              websiteURL: URL(string: "https://www.pacificu.edu/directory/finance-administration/campus-public-safety"),
              contactInfo: "503-352-2230",
              shortDescription: "Campus Public Safety provides safety, first aid and security services for the Pacific University community. Officers respond to all fire, medical and security related calls on campus.  Campus Public Safety Officers are on duty 24-hours a day and are Oregon State Department of Public Safety Standards and Training (DPSST) certified Private Security Professionals."
             ),
        .init(name: "Admissions Office",
              latitude: 45.52243,
              longitude: -123.11142,
              floors: 2,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp access available",
              hoursOpen: "7AM - 5PM",
              websiteURL: URL(string: "https://www.pacificu.edu/admissions/undergraduate-admissions"),
              contactInfo: "(503) 352-2218",
              shortDescription: "Explore our majors and minors, visit our campus, and start your journey to becoming a Pacific University Boxer today."
             ),
        .init(name: "Chapman Hall",
              latitude: 45.52262,
              longitude: -123.11151,
              floors: 2,
              studentServiceOffices: ["Master of Social Work"],
              accessibilityInfo: "Ramp access available",
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "Chapman Hall currently houses the Master of Social Work program."
             ),
        .init(name: "World Language House",
              latitude: 45.52291,
              longitude: -123.11127,
              floors: 2,
              studentServiceOffices: ["Department of World Languages"],
              accessibilityInfo: "Ramp access available",
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "he World Languages Building is home to the Department of World Languages, an undergraduate department featuring programs in Chinese, French, Germany, Japanese and Spanish."
             ),
        .init(name: "Service Center",
              latitude: 45.52114,
              longitude: -123.11117,
              floors: 1,
              studentServiceOffices: nil,
              accessibilityInfo: nil,
              hoursOpen: "7AM - 5PM",
              websiteURL: nil,
              contactInfo: nil,
              shortDescription: "The Rogers Building houses Pacific's Conference & Event Support Services, as well as its Service Center for copying and printing."
             ),
        .init(name: "Outdoor Pursuits",
              latitude: 45.52110,
              longitude: -123.11129,
              floors: 1,
              studentServiceOffices: ["Outdoor Gear & Trips"],
              accessibilityInfo: nil,
              hoursOpen: "10AM - 4PM",
              websiteURL: URL(string: "https://www.pacificu.edu/directory/student-affairs/outdoor-pursuits"),
              contactInfo: "outdoors@pacificu.edu",
              shortDescription: "The Creamery is home to Pacific's Outdoor Pursuits adventure programming — open to students, employees and community members."
             ),
        .init(name: "Old College Hall",
              latitude: 45.52040,
              longitude: -123.11076,
              floors: 2,
              studentServiceOffices: nil,
              accessibilityInfo: "Ramp access available",
              hoursOpen: "7AM - 5PM",
              websiteURL: URL(string: "https://www.pacificu.edu/about/campuses-locations/forest-grove-campus/old-college-hall-museum"),
              contactInfo: "Private tours for research purposes may be arranged by contacting Martha Calus-McLain '03 at 503-352-2057 or martha@pacificu.edu.",
              shortDescription: "Old College Hall was Pacific University's first building, constructed in 1850. It has been moved to different locations on the Forest Grove Campus three times and now is home to a small chapel, gathering space, and the University's museum, open the first Wednesday of each month."
             )
        
    ]



    
    
    private func matchCampusLocation(for building: CampusBuilding) -> CampusLocation {
        // Try to match your rich local data first (best for sheet)
        if let match = campusLocations.first(where: { $0.name.caseInsensitiveCompare(building.name) == .orderedSame }) {
            return match
        }

        // Fallback: create a lightweight location so we can still zoom/select
        return CampusLocation(
            name: building.name,
            latitude: building.latitude,
            longitude: building.longitude,
            floors: nil,
            studentServiceOffices: nil,
            accessibilityInfo: nil,
            hoursOpen: nil,
            websiteURL: nil,
            contactInfo: nil,
            shortDescription: nil
        )
    }
    
    private func endNavigation() {
        activeRoute = nil
        routeSteps = []
        currentStepIndex = 0
        isNavigating = false
        isCalculatingRoute = false
        navigationError = nil
        navigationDestination = nil
    }
    
    @MainActor
    private func startDirections(to location: CampusLocation) async {
        
        selectedLocation = nil
        guard let userCoordinate = locationManager.location?.coordinate else {
            navigationError = "Current location unavailable."
            return
        }

        isCalculatingRoute = true
        navigationError = nil
        currentStepIndex = 0
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.transportType = .walking

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()

            guard let route = response.routes.first else {
                navigationError = "No walking route found."
                isCalculatingRoute = false
                return
            }

            activeRoute = route
            routeSteps = route.steps.filter {
                !$0.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            currentStepIndex = 0;
            isNavigating = true
            isCalculatingRoute = false
            navigationDestination = location


            camera = .rect(route.polyline.boundingMapRect)
            
        } catch {
            navigationError = error.localizedDescription
            isCalculatingRoute = false
        }
    }
    
    
    
    var body: some View {
        Map(position: $camera,selection: $selectedLocation, scope: mapScope) {
            UserAnnotation()
            
            if let activeRoute {
                MapPolyline(activeRoute.polyline)
                    .stroke(.blue, lineWidth: 6)
            }
            
            ForEach(campusLocations) { location in
                    Marker(location.name, coordinate: location.coordinate)
                        .tag(location)
                }
            
        }.onAppear {
            locationManager.requestPermissionAndStart()
        }.mapControls{
            MapUserLocationButton(scope: mapScope)
            MapCompass(scope: mapScope)
            MapScaleView(scope: mapScope)
        }.sheet(item: $selectedLocation) { location in
            LocationPreviewSheet(location: location) { tappedLocation in
                Task {
                    await startDirections(to: tappedLocation)
                }
            }
        }.onChange(of: appState.selectedBuildingID) { _, newID in
            guard let newID else { return }

            // Find the selected CloudKit building
            guard let building = buildingStore.buildings.first(where: { $0.id == newID }) else { return }

            // Convert to a CampusLocation (prefer matching your detailed ones)
            let loc = matchCampusLocation(for: building)

            // 1) Select it (opens sheet + highlights marker because of .tag(location))
            selectedLocation = loc

            // 2) Zoom to it
            camera = .region(
                MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                )
            )
        }.overlay(alignment: .top) {
            if isNavigating, let firstStep = routeSteps.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Step")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(firstStep.instructions)
                        .font(.headline)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.top, 12)
                .padding(.horizontal)
            }
        }.overlay(alignment: .top) {
            if isNavigating, let currentStep {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Direction")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(currentStep.instructions)
                        .font(.headline)

                    if routeSteps.indices.contains(currentStepIndex + 1) {
                        Text("Then: \(routeSteps[currentStepIndex + 1].instructions)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 12)
            }
        }.overlay {
            if isCalculatingRoute {
                ProgressView("Calculating route...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }.overlay(alignment: .bottom) {
            if isNavigating {
                Button(role: .destructive) {
                    endNavigation()
                } label: {
                    Label("Exit Route", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }.overlay(alignment: .bottomTrailing) {
            if isNavigating {
                
                Button {
                    showDirectionsList = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .padding()
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing, 20)
                .padding(.bottom, 90)
            }
        }
        .sheet(isPresented: $showDirectionsList) {
            NavigationStepsView(
                steps: routeSteps,
                currentStepIndex: currentStepIndex,
                destinationName: navigationDestination?.name ?? "Destination"
            )
        }
        .alert("Navigation Error", isPresented: Binding(
            get: { navigationError != nil },
            set: { if !$0 { navigationError = nil } }
        )) {
            Button("OK", role: .cancel) { navigationError = nil }
        } message: {
            Text(navigationError ?? "")
        }
        
    }
}
