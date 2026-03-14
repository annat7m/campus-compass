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

// MARK: - MKMapView annotation and overlay types (for native clustering)

private final class IndoorLocationAnnotation: NSObject, MKAnnotation {
    static let clusteringIdentifier = "indoorRooms"
    let indoorLocation: IndoorLocation
    var coordinate: CLLocationCoordinate2D { indoorLocation.coordinate }
    var title: String? { indoorLocation.name }
    init(_ location: IndoorLocation) {
        self.indoorLocation = location
        super.init()
    }
}

private final class IndoorLabelAnnotation: NSObject, MKAnnotation {
    let label: IndoorLabel
    var coordinate: CLLocationCoordinate2D { label.coordinate }
    var title: String? { label.text }
    init(_ label: IndoorLabel) {
        self.label = label
        super.init()
    }
}

private final class OutdoorPlaceAnnotation: NSObject, MKAnnotation {
    let campusLocation: CampusLocation
    var coordinate: CLLocationCoordinate2D { campusLocation.coordinate }
    var title: String? { campusLocation.name }
    init(_ campusLocation: CampusLocation) {
        self.campusLocation = campusLocation
        super.init()
    }
}

private enum AnnotationReuseId {
    static let indoor = "indoorLocation"
    static let outdoor = "outdoorPlace"
    static let label = "indoorLabel"
    static let cluster = "indoorCluster"
}

/// Wraps a polygon or polyline with kind/use so the delegate can style it.
private final class IndoorShapeOverlay: NSObject, MKOverlay {
    let shape: MKShape
    let kind: IndoorKind
    let use: RoomUse?
    var coordinate: CLLocationCoordinate2D { shape.coordinate }
    var boundingMapRect: MKMapRect {
        if let polygon = shape as? MKPolygon { return polygon.boundingMapRect }
        if let polyline = shape as? MKPolyline { return polyline.boundingMapRect }
        if let multi = shape as? MKMultiPolygon {
            return multi.polygons.map(\.boundingMapRect).reduce(.null) { $0.union($1) }
        }
        if let multi = shape as? MKMultiPolyline {
            return multi.polylines.map(\.boundingMapRect).reduce(.null) { $0.union($1) }
        }
        return .null
    }
    init(shape: MKShape, kind: IndoorKind, use: RoomUse?) {
        self.shape = shape
        self.kind = kind
        self.use = use
        super.init()
    }
}

private final class RouteOverlay: NSObject, MKOverlay {
    let polyline: MKPolyline
    var coordinate: CLLocationCoordinate2D { polyline.coordinate }
    var boundingMapRect: MKMapRect { polyline.boundingMapRect }

    init(polyline: MKPolyline) {
        self.polyline = polyline
        super.init()
    }
}

// MARK: - MKMapView representable with clustering

private struct MKMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var focusedRegion: MKCoordinateRegion?
    let shapesByFloor: [String: [IndoorShape]]
    let labelsByFloor: [String: [IndoorLabel]]
    let locationsByFloor: [String: [IndoorLocation]]
    var selectedFloorId: String
    @Binding var selectedLocation: IndoorLocation?
    let outdoorLocations: [CampusLocation]
    let routePolyline: MKPolyline?
    let onOutdoorSelection: (CampusLocation) -> Void
    let onRegionChange: (MKCoordinateRegion) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.preferredConfiguration = MKStandardMapConfiguration()
        mapView.region = region
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: AnnotationReuseId.indoor)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: AnnotationReuseId.outdoor)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: AnnotationReuseId.label)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: AnnotationReuseId.cluster)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        if let focused = focusedRegion, !regionEquals(focused, context.coordinator.lastAppliedRegion) {
            context.coordinator.lastAppliedRegion = focused
            mapView.setRegion(focused, animated: true)
        }
        let activeShapes = shapesByFloor[selectedFloorId] ?? []
        let activeLocations = activeIndoorLocations()
        let activeLabels = activeAreaLabels()
        let showIndoor = shouldShowIndoorLayer(region: mapView.region)

        context.coordinator.syncOverlays(
            mapView: mapView,
            shapes: activeShapes,
            routePolyline: routePolyline
        )
        context.coordinator.syncAnnotations(
            mapView: mapView,
            indoorLocations: showIndoor ? activeLocations : [],
            labels: showIndoor ? activeLabels : [],
            outdoor: outdoorLocations
        )
    }

    private func regionEquals(_ a: MKCoordinateRegion?, _ b: MKCoordinateRegion?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return a.center.latitude == b.center.latitude && a.center.longitude == b.center.longitude
            && a.span.latitudeDelta == b.span.latitudeDelta && a.span.longitudeDelta == b.span.longitudeDelta
    }

    private func shouldShowIndoorLayer(region: MKCoordinateRegion) -> Bool {
        let halfSpan = region.span.longitudeDelta / 2
        let left = CLLocationCoordinate2D(latitude: region.center.latitude, longitude: region.center.longitude - halfSpan)
        let right = CLLocationCoordinate2D(latitude: region.center.latitude, longitude: region.center.longitude + halfSpan)
        let widthMeters = MKMapPoint(left).distance(to: MKMapPoint(right))
        return widthMeters < 1200
    }

    private func activeIndoorLocations() -> [IndoorLocation] {
        let locations = locationsByFloor[selectedFloorId] ?? []
        var seen = Set<String>()
        return locations.filter { !$0.isArea }.filter { loc in
            let name = loc.name.lowercased()
            if name.contains("server room") { return false }
            let lat = (loc.coordinate.latitude * 100000).rounded() / 100000
            let lon = (loc.coordinate.longitude * 100000).rounded() / 100000
            let key = "\(name)-\(lat)-\(lon)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func activeAreaLabels() -> [IndoorLabel] {
        let labels = labelsByFloor[selectedFloorId] ?? []
        let locationNames = Set(activeIndoorLocations().map { $0.name.lowercased() })
        var seen = Set<String>()
        return labels.filter { label in
            guard label.kind == .area else { return false }
            let name = label.text.lowercased()
            if name.contains("server room") { return false }
            if locationNames.contains(name) { return false }
            let lat = (label.coordinate.latitude * 100000).rounded() / 100000
            let lon = (label.coordinate.longitude * 100000).rounded() / 100000
            let key = "\(label.kind)-\(name)-\(lat)-\(lon)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MKMapViewRepresentable
        var lastAppliedRegion: MKCoordinateRegion?
        var overlayInfo: [ObjectIdentifier: (IndoorKind, RoomUse?)] = [:]
        var indoorLocationAnnotations: [String: IndoorLocationAnnotation] = [:]
        var labelAnnotations: [String: IndoorLabelAnnotation] = [:]
        var outdoorAnnotations: [String: OutdoorPlaceAnnotation] = [:]

        init(_ parent: MKMapViewRepresentable) {
            self.parent = parent
        }

        func syncOverlays(mapView: MKMapView, shapes: [IndoorShape], routePolyline: MKPolyline?) {
            let sorted = shapes.sorted { drawOrder(for: $0.kind) < drawOrder(for: $1.kind) }
            var toAdd: [IndoorShapeOverlay] = []
            for item in sorted {
                if let polygon = item.shape as? MKPolygon {
                    toAdd.append(IndoorShapeOverlay(shape: polygon, kind: item.kind, use: item.use))
                } else if let polyline = item.shape as? MKPolyline, shouldRenderLine(for: item.kind) {
                    toAdd.append(IndoorShapeOverlay(shape: polyline, kind: item.kind, use: item.use))
                } else if let point = item.shape as? MKPointAnnotation, shouldRenderPoint(for: item.kind, use: item.use) {
                    continue
                } else if let multi = item.shape as? MKMultiPolygon {
                    for polygon in multi.polygons {
                        toAdd.append(IndoorShapeOverlay(shape: polygon, kind: item.kind, use: item.use))
                    }
                } else if let multi = item.shape as? MKMultiPolyline, shouldRenderLine(for: item.kind) {
                    for polyline in multi.polylines {
                        toAdd.append(IndoorShapeOverlay(shape: polyline, kind: item.kind, use: item.use))
                    }
                }
            }
            mapView.removeOverlays(mapView.overlays)
            overlayInfo.removeAll()
            for overlay in toAdd {
                mapView.addOverlay(overlay)
                overlayInfo[ObjectIdentifier(overlay)] = (overlay.kind, overlay.use)
            }
            if let routePolyline {
                mapView.addOverlay(RouteOverlay(polyline: routePolyline))
            }
        }

        func syncAnnotations(mapView: MKMapView, indoorLocations: [IndoorLocation], labels: [IndoorLabel], outdoor: [CampusLocation]) {
            var toAdd: [MKAnnotation] = []
            var toRemove: [MKAnnotation] = []

            var desiredIndoorIds = Set<String>()
            for loc in indoorLocations {
                desiredIndoorIds.insert(loc.id)
                if indoorLocationAnnotations[loc.id] == nil {
                    let annotation = IndoorLocationAnnotation(loc)
                    indoorLocationAnnotations[loc.id] = annotation
                    toAdd.append(annotation)
                }
            }
            let removedIndoor = Set(indoorLocationAnnotations.keys).subtracting(desiredIndoorIds)
            for id in removedIndoor {
                if let annotation = indoorLocationAnnotations.removeValue(forKey: id) {
                    toRemove.append(annotation)
                }
            }

            var desiredLabelIds = Set<String>()
            for label in labels {
                desiredLabelIds.insert(label.id)
                if labelAnnotations[label.id] == nil {
                    let annotation = IndoorLabelAnnotation(label)
                    labelAnnotations[label.id] = annotation
                    toAdd.append(annotation)
                }
            }
            let removedLabels = Set(labelAnnotations.keys).subtracting(desiredLabelIds)
            for id in removedLabels {
                if let annotation = labelAnnotations.removeValue(forKey: id) {
                    toRemove.append(annotation)
                }
            }

            var desiredOutdoorIds = Set<String>()
            for location in outdoor {
                let id = outdoorKey(name: location.name, coordinate: location.coordinate)
                desiredOutdoorIds.insert(id)
                if outdoorAnnotations[id] == nil {
                    let annotation = OutdoorPlaceAnnotation(location)
                    outdoorAnnotations[id] = annotation
                    toAdd.append(annotation)
                }
            }
            let removedOutdoor = Set(outdoorAnnotations.keys).subtracting(desiredOutdoorIds)
            for id in removedOutdoor {
                if let annotation = outdoorAnnotations.removeValue(forKey: id) {
                    toRemove.append(annotation)
                }
            }

            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }
            if !toAdd.isEmpty {
                mapView.addAnnotations(toAdd)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationReuseId.cluster, for: cluster) as? MKMarkerAnnotationView
                view?.markerTintColor = .systemGray
                view?.glyphText = "\(cluster.memberAnnotations.count)"
                view?.glyphImage = nil
                view?.glyphTintColor = .white
                view?.clusteringIdentifier = nil
                view?.canShowCallout = false
                return view
            }
            if let indoor = annotation as? IndoorLocationAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationReuseId.indoor, for: indoor) as? MKMarkerAnnotationView
                view?.markerTintColor = markerColor(for: indoor.indoorLocation)
                if let symbol = markerSymbol(for: indoor.indoorLocation) {
                    view?.glyphText = nil
                    view?.glyphImage = UIImage(systemName: symbol)
                } else {
                    view?.glyphImage = nil
                    view?.glyphTintColor = .white
                    view?.glyphText = nil
                }
                view?.clusteringIdentifier = IndoorLocationAnnotation.clusteringIdentifier
                view?.canShowCallout = false
                return view
            }
            if let labelAnn = annotation as? IndoorLabelAnnotation {
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationReuseId.label) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: nil, reuseIdentifier: AnnotationReuseId.label)
                    view?.isEnabled = false
                }
                view?.annotation = labelAnn
                view?.glyphText = labelAnn.label.text
                view?.glyphImage = nil
                view?.markerTintColor = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 0.9)
                view?.glyphTintColor = UIColor(red: 0.28, green: 0.28, blue: 0.32, alpha: 1)
                view?.clusteringIdentifier = nil
                view?.canShowCallout = false
                return view
            }
            if let outdoor = annotation as? OutdoorPlaceAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationReuseId.outdoor, for: outdoor) as? MKMarkerAnnotationView
                view?.markerTintColor = .systemBlue
                view?.glyphText = nil
                view?.glyphImage = nil
                view?.glyphTintColor = nil
                view?.clusteringIdentifier = nil
                view?.canShowCallout = false
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let routeOverlay = overlay as? RouteOverlay {
                let renderer = MKPolylineRenderer(polyline: routeOverlay.polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 6
                return renderer
            }
            guard let shapeOverlay = overlay as? IndoorShapeOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            if let polygon = shapeOverlay.shape as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let (kind, use) = overlayInfo[ObjectIdentifier(shapeOverlay)] ?? (.unknown, nil)
                renderer.fillColor = fillColor(for: kind, use: use)
                renderer.strokeColor = strokeColor(for: kind, use: use)
                renderer.lineWidth = lineWidth(for: kind, use: use)
                return renderer
            }
            if let polyline = shapeOverlay.shape as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                let (kind, use) = overlayInfo[ObjectIdentifier(shapeOverlay)] ?? (.unknown, nil)
                renderer.strokeColor = strokeColor(for: kind, use: use)
                renderer.lineWidth = lineWidth(for: kind, use: use)
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let ann = view.annotation as? IndoorLocationAnnotation {
                parent.selectedLocation = ann.indoorLocation
                mapView.deselectAnnotation(view.annotation, animated: true)
                return
            }
            if let ann = view.annotation as? OutdoorPlaceAnnotation {
                parent.onOutdoorSelection(ann.campusLocation)
                mapView.deselectAnnotation(view.annotation, animated: true)
                return
            }
            if view.annotation is MKClusterAnnotation {
                mapView.deselectAnnotation(view.annotation, animated: true)
                return
            }
            mapView.deselectAnnotation(view.annotation, animated: true)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            parent.onRegionChange(mapView.region)
        }

        func mapView(_ mapView: MKMapView, clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
            MKClusterAnnotation(memberAnnotations: memberAnnotations)
        }

        private func outdoorKey(name: String, coordinate: CLLocationCoordinate2D) -> String {
            let lat = (coordinate.latitude * 100000).rounded() / 100000
            let lon = (coordinate.longitude * 100000).rounded() / 100000
            return "\(name.lowercased())-\(lat)-\(lon)"
        }

        private func drawOrder(for kind: IndoorKind) -> Int {
            switch kind {
            case .area: return 0
            case .hallway: return 1
            case .room: return 2
            case .object: return 3
            case .window: return 4
            case .wall: return 5
            case .door: return 6
            case .outline: return 7
            case .unknown: return 8
            }
        }

        private func strokeColor(for kind: IndoorKind, use: RoomUse?) -> UIColor {
            switch kind {
            case .outline: return .systemBlue
            case .wall: return .label
            case .window: return .cyan
            case .door: return .systemGreen
            case .room, .hallway, .area, .object: return .gray
            case .unknown: return .gray
            }
        }

        private func fillColor(for kind: IndoorKind, use: RoomUse?) -> UIColor {
            switch kind {
            case .room, .hallway, .area, .object:
                return UIColor.gray.withAlphaComponent(0.12)
            default:
                return .clear
            }
        }

        private func lineWidth(for kind: IndoorKind, use: RoomUse?) -> CGFloat {
            switch kind {
            case .outline: return 0.8
            case .wall: return 1.6
            case .door: return 2.2
            case .window: return 1.2
            case .room, .hallway, .area, .object: return 0.8
            case .unknown: return 1.0
            }
        }

        private func shouldRenderPoint(for kind: IndoorKind, use: RoomUse?) -> Bool {
            if use == .stairs || use == .elevator { return false }
            switch kind {
            case .door, .object: return true
            default: return false
            }
        }

        private func shouldRenderLine(for kind: IndoorKind) -> Bool {
            switch kind {
            case .wall, .window, .door, .outline: return true
            default: return false
            }
        }

        private func markerColor(for location: IndoorLocation) -> UIColor {
            switch location.use {
            case .bathroom: return UIColor(red: 0.49, green: 0.69, blue: 0.92, alpha: 1)
            case .classroom: return UIColor(red: 0.62, green: 0.55, blue: 0.86, alpha: 1)
            case .stairs: return UIColor(red: 0.78, green: 0.62, blue: 0.35, alpha: 1)
            case .elevator: return UIColor(red: 0.36, green: 0.69, blue: 0.46, alpha: 1)
            case .none:
                if location.categories.contains(where: { $0.localizedCaseInsensitiveContains("cafe") || $0.localizedCaseInsensitiveContains("food") }) {
                    return UIColor(red: 0.86, green: 0.55, blue: 0.25, alpha: 1)
                }
                return UIColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1)
            }
        }

        private func markerSymbol(for location: IndoorLocation) -> String? {
            if location.use == .bathroom { return "figure.stand" }
            if location.use == .stairs { return "stairs" }
            if location.use == .elevator { return "arrow.up.and.down" }
            if location.categories.contains(where: { $0.localizedCaseInsensitiveContains("cafe") || $0.localizedCaseInsensitiveContains("food") }) {
                return "cup.and.saucer.fill"
            }
            if location.categories.contains(where: { $0.localizedCaseInsensitiveContains("lab") }) {
                return "testtube.2"
            }
            if location.categories.contains(where: { $0.localizedCaseInsensitiveContains("book") }) {
                return "book.fill"
            }
            return nil
        }
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
    @State private var hasCenteredOnUser = false
    @State private var selectedOutdoorLocation: CampusLocation?
    @State private var indoorBuildings: [IndoorBuilding] = []
    @State private var indoorShapesByFloor: [String: [IndoorShape]] = [:]
    @State private var indoorLabelsByFloor: [String: [IndoorLabel]] = [:]
    @State private var indoorLocationsByFloor: [String: [IndoorLocation]] = [:]
    @State private var selectedBuildingId: String = ""
    @State private var selectedFloorId: String = ""
    @State private var selectedIndoorLocation: IndoorLocation?
    @State private var detailDetent: PresentationDetent = .height(220)
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.521, longitude: -123.108),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var focusedRegion: MKCoordinateRegion?
    
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
              websiteURL: nil,
              contactInfo: "503-352-2200",
              shortDescription: nil
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

    private var displayedOutdoorLocations: [CampusLocation] {
        var merged = campusLocations
        var seen = Set(merged.map { normalizedOutdoorKey(name: $0.name) })

        for building in buildingStore.buildings {
            let location = matchCampusLocation(for: building)
            let key = normalizedOutdoorKey(name: location.name)
            if seen.insert(key).inserted {
                merged.append(location)
            }
        }

        return merged
    }

    private func normalizedOutdoorKey(name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }


    
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
        
        selectedOutdoorLocation = nil
        selectedIndoorLocation = nil
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

            let routeRect = route.polyline.boundingMapRect
            let padded = routeRect.insetBy(dx: -routeRect.size.width * 0.15, dy: -routeRect.size.height * 0.15)
            focusedRegion = MKCoordinateRegion(padded)
            
        } catch {
            navigationError = error.localizedDescription
            isCalculatingRoute = false
        }
    }
    
    
    
    var body: some View {
        MKMapViewRepresentable(
            region: $mapRegion,
            focusedRegion: focusedRegion,
            shapesByFloor: indoorShapesByFloor,
            labelsByFloor: indoorLabelsByFloor,
            locationsByFloor: indoorLocationsByFloor,
            selectedFloorId: selectedFloorId,
            selectedLocation: $selectedIndoorLocation,
            outdoorLocations: displayedOutdoorLocations,
            routePolyline: activeRoute?.polyline,
            onOutdoorSelection: { location in
                selectedIndoorLocation = nil
                selectedOutdoorLocation = location
            },
            onRegionChange: { newRegion in
                let halfSpan = newRegion.span.longitudeDelta / 2
                let left = CLLocationCoordinate2D(
                    latitude: newRegion.center.latitude,
                    longitude: newRegion.center.longitude - halfSpan
                )
                let right = CLLocationCoordinate2D(
                    latitude: newRegion.center.latitude,
                    longitude: newRegion.center.longitude + halfSpan
                )
                let widthMeters = MKMapPoint(left).distance(to: MKMapPoint(right))
                if widthMeters >= 1200 {
                    selectedIndoorLocation = nil
                }
            }
        )
        .ignoresSafeArea()
        .task {
            guard indoorBuildings.isEmpty else { return }
            let data = IndoorDataLoader.loadCampusIndoorData()
            indoorBuildings = data.buildings
            indoorShapesByFloor = data.shapesByFloor
            indoorLabelsByFloor = data.labelsByFloor
            indoorLocationsByFloor = data.locationsByFloor
            syncSelection(with: data.buildings)
        }
        .onAppear {
            locationManager.requestPermissionAndStart()
        }
        .onReceive(locationManager.$location) { location in
            guard let location, !hasCenteredOnUser else { return }
            hasCenteredOnUser = true
            focusedRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        .onChange(of: appState.selectedBuildingID) { _, newID in
            guard let newID else { return }
            guard let building = buildingStore.buildings.first(where: { $0.id == newID }) else { return }

            let location = matchCampusLocation(for: building)
            selectedIndoorLocation = nil
            selectedOutdoorLocation = location
            focusedRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        }
        .onChange(of: selectedBuildingId) { _, newValue in
            guard let building = indoorBuildings.first(where: { $0.id == newValue }) else { return }
            guard !building.floors.isEmpty else {
                selectedFloorId = ""
                return
            }
            let defaultId = building.floors.first { $0.id == building.defaultFloorId }?.id
                ?? building.floors.first?.id ?? ""
            if !defaultId.isEmpty {
                selectedFloorId = defaultId
                focusOnBuilding(floorId: defaultId)
            }
        }
        .onChange(of: selectedIndoorLocation?.id) { _, newValue in
            if newValue != nil {
                selectedOutdoorLocation = nil
                detailDetent = .height(220)
            }
        }
        .onChange(of: selectedOutdoorLocation?.id) { _, newValue in
            if newValue != nil {
                selectedIndoorLocation = nil
            }
        }
        .overlay(alignment: .trailing) {
            if !visibleFloors.isEmpty {
                VStack {
                    Spacer()
                    FloorStack(floors: visibleFloors, selection: $selectedFloorId)
                }
                .padding(.trailing, 12)
                .padding(.bottom, 120)
            }
        }
        .overlay(alignment: .topLeading) {
            if !indoorBuildings.isEmpty {
                BuildingPicker(buildings: indoorBuildings, selection: $selectedBuildingId)
                    .padding(.leading, 12)
                    .padding(.top, 60)
            }
        }
        .overlay(alignment: .top) {
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
        }
        .overlay {
            if isCalculatingRoute {
                ProgressView("Calculating route...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay(alignment: .bottom) {
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
        }
        .overlay(alignment: .bottomTrailing) {
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
        .sheet(item: $selectedOutdoorLocation) { location in
            LocationPreviewSheet(location: location) { tappedLocation in
                Task {
                    await startDirections(to: tappedLocation)
                }
            }
        }
        .sheet(item: $selectedIndoorLocation) { location in
            IndoorLocationDetailView(location: location)
                .presentationDetents([.height(220), .medium, .large], selection: $detailDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
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

    private var visibleFloors: [IndoorFloor] {
        indoorBuildings.first(where: { $0.id == selectedBuildingId })?.floors ?? []
    }

    private func syncSelection(with buildings: [IndoorBuilding]) {
        let resolvedBuilding: IndoorBuilding?
        if selectedBuildingId.isEmpty {
            resolvedBuilding = buildings.first(where: { $0.id == "overview" })
                ?? buildings.first(where: { !$0.floors.isEmpty })
                ?? buildings.first
        } else {
            resolvedBuilding = buildings.first(where: { $0.id == selectedBuildingId })
                ?? buildings.first(where: { !$0.floors.isEmpty })
                ?? buildings.first
        }
        guard let activeBuilding = resolvedBuilding else {
            selectedBuildingId = ""
            selectedFloorId = ""
            return
        }

        if selectedBuildingId != activeBuilding.id {
            selectedBuildingId = activeBuilding.id
        }

        guard !activeBuilding.floors.isEmpty else {
            selectedFloorId = ""
            return
        }

        let floorIds = Set(activeBuilding.floors.map { $0.id })
        if !floorIds.contains(selectedFloorId) {
            let defaultId = activeBuilding.floors.first { $0.id == activeBuilding.defaultFloorId }?.id
                ?? activeBuilding.floors.first?.id ?? ""
            selectedFloorId = defaultId
        }
    }

    private func focusOnBuilding(floorId: String) {
        guard let rect = mapRect(for: floorId) else { return }
        guard rect.size.width > 0, rect.size.height > 0 else { return }

        let padded = rect.insetBy(dx: -rect.size.width * 0.25, dy: -rect.size.height * 0.25)
        focusedRegion = MKCoordinateRegion(padded)
    }

    private func mapRect(for floorId: String) -> MKMapRect? {
        guard let shapes = indoorShapesByFloor[floorId] else { return nil }
        var rect: MKMapRect?
        for shape in shapes {
            guard let geometryRect = mapRect(for: shape.shape) else { continue }
            rect = rect.map { $0.union(geometryRect) } ?? geometryRect
        }
        return rect
    }

    private func mapRect(for shape: MKShape) -> MKMapRect? {
        if let polygon = shape as? MKPolygon {
            return polygon.boundingMapRect
        }
        if let polyline = shape as? MKPolyline {
            return polyline.boundingMapRect
        }
        if let multiPolygon = shape as? MKMultiPolygon {
            return unionRects(multiPolygon.polygons.map(\.boundingMapRect))
        }
        if let multiPolyline = shape as? MKMultiPolyline {
            return unionRects(multiPolyline.polylines.map(\.boundingMapRect))
        }
        if let point = shape as? MKPointAnnotation {
            let mapPoint = MKMapPoint(point.coordinate)
            let size = MKMapSize(width: 200, height: 200)
            return MKMapRect(
                origin: MKMapPoint(x: mapPoint.x - size.width / 2, y: mapPoint.y - size.height / 2),
                size: size
            )
        }
        return nil
    }

    private func unionRects(_ rects: [MKMapRect]) -> MKMapRect? {
        var combined: MKMapRect?
        for rect in rects {
            combined = combined.map { $0.union(rect) } ?? rect
        }
        return combined
    }
}

private struct IndoorLocationDetailView: View {
    let location: IndoorLocation

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(location.name)
                            .font(.title2.weight(.semibold))
                        if let description = location.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !location.categories.isEmpty {
                            Text(location.categories.joined(separator: " • "))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !location.openingHours.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hours")
                                .font(.headline)
                            ForEach(location.openingHours) { entry in
                                Text(formatHours(entry))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let website = location.website?.url, !website.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Website")
                                .font(.headline)
                            Text(location.website?.label ?? website)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatHours(_ entry: IndoorOpeningHours) -> String {
        let days = entry.days.joined(separator: ", ")
        let isClosed = entry.opens == "00:00" && entry.closes == "00:00"
        if isClosed {
            return "\(days): Closed"
        }
        return "\(days): \(entry.opens) – \(entry.closes)"
    }
}

private struct BuildingPicker: View {
    let buildings: [IndoorBuilding]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(buildings) { building in
                Button(building.name) {
                    selection = building.id
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentName)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var currentName: String {
        buildings.first(where: { $0.id == selection })?.name ?? "Building"
    }
}

private struct FloorStack: View {
    let floors: [IndoorFloor]
    @Binding var selection: String

    var body: some View {
        VStack(spacing: 10) {
            ForEach(floors) { floor in
                Button {
                    selection = floor.id
                } label: {
                    Text(shortLabel(for: floor))
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(selection == floor.id ? .primary : .secondary)
                        .background(
                            Circle()
                                .fill(selection == floor.id ? Color.white.opacity(0.6) : Color.clear)
                        )
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func shortLabel(for floor: IndoorFloor) -> String {
        let name = floor.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = name.lowercased()

        if lower.contains("ground") { return "G" }
        if lower.contains("street") { return "ST" }
        if lower.contains("lower") { return "LL" }
        if lower.contains("basement") { return "B" }

        if let number = firstNumber(in: name) {
            return "L\(number)"
        }

        if name.count >= 2 {
            return String(name.prefix(2)).uppercased()
        }
        return name.uppercased()
    }

    private func firstNumber(in text: String) -> String? {
        let digits = text.compactMap { $0.isNumber ? $0 : nil }
        guard !digits.isEmpty else { return nil }
        return String(digits)
    }
}
