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
    @State private var hasCenteredOnUser = false
    @State private var indoorBuildings: [IndoorBuilding] = []
    @State private var indoorFeaturesByFloor: [String: [MKGeoJSONFeature]] = [:]
    @State private var selectedBuildingId: String = ""
    @State private var selectedFloorId: String = ""

    let UCLoc = CLLocationCoordinate2D(latitude: 45.52207, longitude: -123.10894)
    let Strain = CLLocationCoordinate2D(latitude: 45.52180, longitude: -123.10723)
    let Aucoin = CLLocationCoordinate2D(latitude: 45.52142, longitude: -123.10982)
    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
            
            Marker("University Center", coordinate: UCLoc)
            Marker("Strain Science Center", coordinate: Strain)
            Marker("Aucoin Hall", coordinate: Aucoin)

            IndoorMapLayer(features: activeIndoorFeatures)
        }
        .task {
            let data = IndoorDataLoader.loadCampusIndoorData()
            indoorBuildings = data.buildings
            indoorFeaturesByFloor = data.featuresByFloor
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

            camera = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
        .ignoresSafeArea()
    }

    private var activeIndoorFeatures: [MKGeoJSONFeature] {
        indoorFeaturesByFloor[selectedFloorId] ?? []
    }

    private var visibleFloors: [IndoorFloor] {
        indoorBuildings.first(where: { $0.id == selectedBuildingId })?.floors ?? []
    }

    private func syncSelection(with buildings: [IndoorBuilding]) {
        let resolvedBuilding = buildings.first(where: { $0.id == selectedBuildingId })
            ?? buildings.first(where: { !$0.floors.isEmpty })
            ?? buildings.first
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
        let region = MKCoordinateRegion(padded)
        withAnimation(.easeInOut(duration: 0.35)) {
            camera = .region(region)
        }
    }

    private func mapRect(for floorId: String) -> MKMapRect? {
        guard let features = indoorFeaturesByFloor[floorId] else { return nil }
        var rect: MKMapRect?
        for feature in features {
            for geometry in feature.geometry {
                guard let geometryRect = mapRect(for: geometry) else { continue }
                rect = rect.map { $0.union(geometryRect) } ?? geometryRect
            }
        }
        return rect
    }

    private func mapRect(for geometry: MKShape & MKGeoJSONObject) -> MKMapRect? {
        if let polygon = geometry as? MKPolygon {
            return polygon.boundingMapRect
        }
        if let polyline = geometry as? MKPolyline {
            return polyline.boundingMapRect
        }
        if let multiPolygon = geometry as? MKMultiPolygon {
            return unionRects(multiPolygon.polygons.map(\.boundingMapRect))
        }
        if let multiPolyline = geometry as? MKMultiPolyline {
            return unionRects(multiPolyline.polylines.map(\.boundingMapRect))
        }
        if let point = geometry as? MKPointAnnotation {
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

private struct IndoorMapLayer: MapContent {
    let features: [MKGeoJSONFeature]

    var body: some MapContent {
        ForEach(features.indices, id: \.self) { fIdx in
            let feature = features[fIdx]
            ForEach(feature.geometry.indices, id: \.self) { gIdx in
                let shape = feature.geometry[gIdx]
                if let poly = shape as? MKPolygon {
                    MapPolygon(poly)
                        .foregroundStyle(.clear)
                        .stroke(.blue, lineWidth: 2)
                } else if let line = shape as? MKPolyline {
                    MapPolyline(line)
                        .stroke(.orange, lineWidth: 2)
                } else if let point = shape as? MKPointAnnotation {
                    Annotation(point.title ?? "POI", coordinate: point.coordinate) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                    }
                }
            }
        }
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
