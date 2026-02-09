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
    @State private var indoorFloors: [IndoorFloor] = []
    @State private var indoorFeaturesByFloor: [String: [MKGeoJSONFeature]] = [:]
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
            let data = loadIndoorData()
            indoorFloors = data.floors
            indoorFeaturesByFloor = data.featuresByFloor
            if selectedFloorId.isEmpty, let first = data.floors.first?.id {
                selectedFloorId = first
            }
        }
        .overlay(alignment: .trailing) {
            if !indoorFloors.isEmpty {
                VStack {
                    Spacer()
                    FloorStack(floors: indoorFloors, selection: $selectedFloorId)
                }
                .padding(.trailing, 12)
                .padding(.bottom, 120)
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
}

private struct IndoorFloor: Identifiable {
    let id: String
    let name: String
    let elevation: Double
}

private struct IndoorData {
    let floors: [IndoorFloor]
    let featuresByFloor: [String: [MKGeoJSONFeature]]

    static let empty = IndoorData(floors: [], featuresByFloor: [:])
}

private func loadIndoorData() -> IndoorData {
    let folderName = "IndoorGeoJSON"
    guard let baseURL = Bundle.main.resourceURL?.appendingPathComponent(folderName) else {
        return .empty
    }

    let decoder = MKGeoJSONDecoder()
    var floors: [IndoorFloor] = []
    var featuresByFloor: [String: [MKGeoJSONFeature]] = [:]
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: baseURL,
                                         includingPropertiesForKeys: [.isRegularFileKey],
                                         options: [.skipsHiddenFiles]) else {
        return .empty
    }

    for case let fileURL as URL in enumerator {
        let ext = fileURL.pathExtension.lowercased()
        guard ext == "json" || ext == "geojson" else { continue }

        let fileName = fileURL.lastPathComponent.lowercased()
        if fileName == "floors.geojson" || fileName == "floor.geojson" {
            floors.append(contentsOf: decodeFloors(from: fileURL, decoder: decoder))
            continue
        }

        let floorId = fileURL.deletingPathExtension().lastPathComponent
        guard floorId.hasPrefix("f_") else { continue }

        do {
            let data = try Data(contentsOf: fileURL)
            let objects = try decoder.decode(data)
            for obj in objects {
                if let feature = obj as? MKGeoJSONFeature {
                    featuresByFloor[floorId, default: []].append(feature)
                }
            }
        } catch {
            print("IndoorGeoJSON load failed for \(fileURL.lastPathComponent): \(error)")
        }
    }

    if floors.isEmpty {
        let ids = featuresByFloor.keys.sorted()
        floors = ids.map { IndoorFloor(id: $0, name: $0, elevation: 0) }
    } else {
        floors.sort { $0.elevation < $1.elevation }
    }

    return IndoorData(floors: floors, featuresByFloor: featuresByFloor)
}

private func decodeFloors(from url: URL, decoder: MKGeoJSONDecoder) -> [IndoorFloor] {
    do {
        let data = try Data(contentsOf: url)
        let objects = try decoder.decode(data)
        var result: [IndoorFloor] = []
        for obj in objects {
            guard let feature = obj as? MKGeoJSONFeature,
                  let floor = parseFloor(feature) else { continue }
            result.append(floor)
        }
        return result
    } catch {
        print("IndoorGeoJSON floor load failed for \(url.lastPathComponent): \(error)")
        return []
    }
}

private func parseFloor(_ feature: MKGeoJSONFeature) -> IndoorFloor? {
    guard let data = feature.properties,
          let props = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let id = props["id"] as? String else {
        return nil
    }

    let details = props["details"] as? [String: Any]
    let name = (details?["name"] as? String) ?? id
    let elevation: Double
    if let value = props["elevation"] as? Double {
        elevation = value
    } else if let value = props["elevation"] as? Int {
        elevation = Double(value)
    } else {
        elevation = 0
    }

    return IndoorFloor(id: id, name: name, elevation: elevation)
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
                        .foregroundStyle(.blue.opacity(0.2))
                        .stroke(.blue, lineWidth: 1)
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
