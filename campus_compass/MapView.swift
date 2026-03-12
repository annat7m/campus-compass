//
//  MapView.swift
//  Campus Compass
//
//  Created by Anna Tymoshenko on 10/10/25.
//

import SwiftUI
import MapKit

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
    let name: String
    let coordinate: CLLocationCoordinate2D
    var title: String? { name }
    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.coordinate = coordinate
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

// MARK: - MKMapView representable with clustering

private struct MKMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var focusedRegion: MKCoordinateRegion?
    let buildings: [IndoorBuilding]
    let shapesByFloor: [String: [IndoorShape]]
    let labelsByFloor: [String: [IndoorLabel]]
    let locationsByFloor: [String: [IndoorLocation]]
    var selectedBuildingId: String
    var selectedFloorId: String
    @Binding var selectedLocation: IndoorLocation?
    let outdoorMarkers: [(name: String, coordinate: CLLocationCoordinate2D)]
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
        if let focused = focusedRegion, !regionEquals(focused, context.coordinator.lastAppliedRegion) {
            context.coordinator.lastAppliedRegion = focused
            mapView.setRegion(focused, animated: true)
        }
        let activeShapes = shapesByFloor[selectedFloorId] ?? []
        let activeLocations = activeIndoorLocations(context.coordinator)
        let activeLabels = activeAreaLabels(context.coordinator)
        let showIndoor = shouldShowIndoorLayer(region: mapView.region)

        context.coordinator.syncOverlays(mapView: mapView, shapes: activeShapes)
        context.coordinator.syncAnnotations(
            mapView: mapView,
            indoorLocations: showIndoor ? activeLocations : [],
            labels: showIndoor ? activeLabels : [],
            outdoor: outdoorMarkers
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

    private func activeIndoorLocations(_ coordinator: Coordinator) -> [IndoorLocation] {
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

    private func activeAreaLabels(_ coordinator: Coordinator) -> [IndoorLabel] {
        let labels = labelsByFloor[selectedFloorId] ?? []
        let locationNames = Set(activeIndoorLocations(coordinator).map { $0.name.lowercased() })
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

        func syncOverlays(mapView: MKMapView, shapes: [IndoorShape]) {
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
        }

        func syncAnnotations(mapView: MKMapView, indoorLocations: [IndoorLocation], labels: [IndoorLabel], outdoor: [(name: String, coordinate: CLLocationCoordinate2D)]) {
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
            for m in outdoor {
                let id = outdoorKey(name: m.name, coordinate: m.coordinate)
                desiredOutdoorIds.insert(id)
                if outdoorAnnotations[id] == nil {
                    let annotation = OutdoorPlaceAnnotation(name: m.name, coordinate: m.coordinate)
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
            guard let ann = view.annotation as? IndoorLocationAnnotation else {
                if view.annotation is MKClusterAnnotation {
                    mapView.deselectAnnotation(view.annotation, animated: true)
                }
                return
            }
            parent.selectedLocation = ann.indoorLocation
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
    @StateObject private var locationManager = LocationManager()
    @State private var hasCenteredOnUser = false
    @State private var indoorBuildings: [IndoorBuilding] = []
    @State private var indoorShapesByFloor: [String: [IndoorShape]] = [:]
    @State private var indoorLabelsByFloor: [String: [IndoorLabel]] = [:]
    @State private var indoorLocationsByFloor: [String: [IndoorLocation]] = [:]
    @State private var selectedBuildingId: String = ""
    @State private var selectedFloorId: String = ""
    @State private var selectedLocation: IndoorLocation? = nil
    @State private var detailDetent: PresentationDetent = .height(220)
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.521, longitude: -123.108),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var focusedRegion: MKCoordinateRegion?

    private let outdoorMarkers: [(name: String, coordinate: CLLocationCoordinate2D)] = [
        ("University Center", CLLocationCoordinate2D(latitude: 45.52207, longitude: -123.10894)),
        ("Strain Science Center", CLLocationCoordinate2D(latitude: 45.52180, longitude: -123.10723)),
        ("Aucoin Hall", CLLocationCoordinate2D(latitude: 45.52142, longitude: -123.10982)),
        ("Murdock Hall", CLLocationCoordinate2D(latitude: 45.52136, longitude: -123.10679)),
    ]

    var body: some View {
        MKMapViewRepresentable(
            region: $mapRegion,
            focusedRegion: focusedRegion,
            buildings: indoorBuildings,
            shapesByFloor: indoorShapesByFloor,
            labelsByFloor: indoorLabelsByFloor,
            locationsByFloor: indoorLocationsByFloor,
            selectedBuildingId: selectedBuildingId,
            selectedFloorId: selectedFloorId,
            selectedLocation: $selectedLocation,
            outdoorMarkers: outdoorMarkers,
            onRegionChange: { newRegion in
                let halfSpan = newRegion.span.longitudeDelta / 2
                let left = CLLocationCoordinate2D(latitude: newRegion.center.latitude, longitude: newRegion.center.longitude - halfSpan)
                let right = CLLocationCoordinate2D(latitude: newRegion.center.latitude, longitude: newRegion.center.longitude + halfSpan)
                let widthMeters = MKMapPoint(left).distance(to: MKMapPoint(right))
                if widthMeters >= 1200 {
                    selectedLocation = nil
                }
            }
        )
        .task {
            let data = IndoorDataLoader.loadCampusIndoorData()
            indoorBuildings = data.buildings
            indoorShapesByFloor = data.shapesByFloor
            indoorLabelsByFloor = data.labelsByFloor
            indoorLocationsByFloor = data.locationsByFloor
            syncSelection(with: data.buildings)
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
        .onReceive(locationManager.$location) { location in
            guard let location, !hasCenteredOnUser else { return }
            hasCenteredOnUser = true
            focusedRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        .ignoresSafeArea()
        .sheet(item: $selectedLocation) { location in
            IndoorLocationDetailView(location: location)
                .presentationDetents([.height(220), .medium, .large], selection: $detailDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
        .onChange(of: selectedLocation?.id) { _, newValue in
            if newValue != nil {
                detailDetent = .height(220)
            }
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
            return MKMapRect(origin: MKMapPoint(x: mapPoint.x - size.width / 2,
                                                y: mapPoint.y - size.height / 2),
                             size: size)
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
