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
    @State private var indoorShapesByFloor: [String: [IndoorShape]] = [:]
    @State private var indoorLabelsByFloor: [String: [IndoorLabel]] = [:]
    @State private var indoorLocationsByFloor: [String: [IndoorLocation]] = [:]
    @State private var selectedBuildingId: String = ""
    @State private var selectedFloorId: String = ""
    @State private var selectedLocation: IndoorLocation? = nil
    @State private var detailDetent: PresentationDetent = .height(220)

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

            IndoorMapLayer(shapes: activeIndoorShapes)
            IndoorLocationMarkersLayer(locations: activeIndoorLocations, selection: $selectedLocation)
            IndoorAreaLabelsLayer(labels: activeAreaLabels)
        }
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

            camera = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
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

    private var activeIndoorShapes: [IndoorShape] {
        let shapes = indoorShapesByFloor[selectedFloorId] ?? []
        return shapes.sorted { drawOrder(for: $0.kind) < drawOrder(for: $1.kind) }
    }

    private var activeIndoorLabels: [IndoorLabel] {
        let labels = indoorLabelsByFloor[selectedFloorId] ?? []
        var seen = Set<String>()
        return labels.filter { label in
            let lat = (label.coordinate.latitude * 100000).rounded() / 100000
            let lon = (label.coordinate.longitude * 100000).rounded() / 100000
            let key = "\(label.kind)-\(label.text.lowercased())-\(lat)-\(lon)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private var activeAreaLabels: [IndoorLabel] {
        let locationNames = Set(activeIndoorLocations.map { $0.name.lowercased() })
        return activeIndoorLabels.filter { label in
            guard label.kind == .area else { return false }
            let name = label.text.lowercased()
            if name.contains("server room") { return false }
            return !locationNames.contains(name)
        }
    }

    private var activeIndoorLocations: [IndoorLocation] {
        let locations = indoorLocationsByFloor[selectedFloorId] ?? []
        var seen = Set<String>()
        return locations.filter { !$0.isArea }.filter { location in
            let name = location.name.lowercased()
            if name.contains("server room") { return false }
            let lat = (location.coordinate.latitude * 100000).rounded() / 100000
            let lon = (location.coordinate.longitude * 100000).rounded() / 100000
            let key = "\(location.name.lowercased())-\(lat)-\(lon)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
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
        let region = MKCoordinateRegion(padded)
        withAnimation(.easeInOut(duration: 0.35)) {
            camera = .region(region)
        }
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
}

private struct IndoorMapLayer: MapContent {
    let shapes: [IndoorShape]

    var body: some MapContent {
        ForEach(shapes) { item in
            if let polygon = item.shape as? MKPolygon {
                MapPolygon(polygon)
                    .foregroundStyle(fillColor(for: item.kind, use: item.use))
                    .stroke(strokeColor(for: item.kind, use: item.use),
                            lineWidth: lineWidth(for: item.kind, use: item.use))
            } else if let polyline = item.shape as? MKPolyline {
                if shouldRenderLine(for: item.kind) {
                    MapPolyline(polyline)
                        .stroke(strokeColor(for: item.kind, use: item.use),
                                lineWidth: lineWidth(for: item.kind, use: item.use))
                }
            } else if let point = item.shape as? MKPointAnnotation, shouldRenderPoint(for: item.kind, use: item.use) {
                Annotation("", coordinate: point.coordinate) {
                    Circle()
                        .fill(strokeColor(for: item.kind, use: item.use))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    private func strokeColor(for kind: IndoorKind, use: RoomUse?) -> Color {
        switch kind {
        case .outline: return .blue
        case .wall: return .primary
        case .window: return .cyan
        case .door: return .green
        case .room, .hallway, .area, .object: return .gray
        case .unknown: return .gray
        }
    }

    private func fillColor(for kind: IndoorKind, use: RoomUse?) -> Color {
        switch kind {
        case .room, .hallway, .area, .object:
            return Color.gray.opacity(0.12)
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
        if use == .stairs || use == .elevator {
            return false
        }
        switch kind {
        case .door, .object: return true
        default: return false
        }
    }

    private func shouldRenderLine(for kind: IndoorKind) -> Bool {
        switch kind {
        case .wall, .window, .door, .outline:
            return true
        default:
            return false
        }
    }

    private func fillColor(for use: RoomUse) -> Color {
        Color.gray.opacity(0.12)
    }

    private func accentColor(for use: RoomUse) -> Color {
        Color.gray
    }
}

private struct IndoorLocationMarkersLayer: MapContent {
    let locations: [IndoorLocation]
    @Binding var selection: IndoorLocation?

    var body: some MapContent {
        ForEach(locations) { location in
            Annotation("", coordinate: location.coordinate) {
                let isSelected = selection?.id == location.id
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = location
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(markerColor(for: location))
                                .frame(width: isSelected ? 36 : 28,
                                       height: isSelected ? 36 : 28)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                            Image(systemName: markerSymbol(for: location))
                                .font(.system(size: isSelected ? 16 : 12, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        if isSelected {
                            Text(location.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                        }
                    }
                    .padding(6)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }

    private func markerColor(for location: IndoorLocation) -> Color {
        switch location.use {
        case .bathroom: return Color(red: 0.49, green: 0.69, blue: 0.92)
        case .classroom: return Color(red: 0.62, green: 0.55, blue: 0.86)
        case .stairs: return Color(red: 0.78, green: 0.62, blue: 0.35)
        case .elevator: return Color(red: 0.36, green: 0.69, blue: 0.46)
        case .none:
            if location.categories.contains(where: { $0.localizedCaseInsensitiveContains("cafe") || $0.localizedCaseInsensitiveContains("food") }) {
                return Color(red: 0.86, green: 0.55, blue: 0.25)
            }
            return Color(red: 0.35, green: 0.35, blue: 0.4)
        }
    }

    private func markerSymbol(for location: IndoorLocation) -> String {
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
        return "mappin.circle.fill"
    }
}

private struct IndoorAreaLabelsLayer: MapContent {
    let labels: [IndoorLabel]

    var body: some MapContent {
        ForEach(labels) { label in
            Annotation("", coordinate: label.coordinate) {
                Text(label.text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.28, green: 0.28, blue: 0.32))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.96, green: 0.96, blue: 0.98, opacity: 0.9))
                    )
            }
        }
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
