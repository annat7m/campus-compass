//
//  IndoorDataLoader.swift
//  Campus Compass
//
//  Created by Codex on 2/24/26.
//

import Foundation
import MapKit

struct IndoorFloor: Identifiable, Hashable {
    let id: String
    let name: String
    let elevation: Double
}

struct IndoorBuilding: Identifiable, Hashable {
    let id: String
    let name: String
    let floors: [IndoorFloor]
    let defaultFloorId: String
}

enum IndoorKind: String {
    case outline
    case wall
    case window
    case room
    case hallway
    case area
    case object
    case door
    case unknown

    init(kind: String?) {
        guard let kind else {
            self = .unknown
            return
        }
        switch kind.lowercased() {
        case "wall": self = .wall
        case "window": self = .window
        case "room": self = .room
        case "hallway": self = .hallway
        case "area": self = .area
        case "object": self = .object
        default: self = .unknown
        }
    }
}

enum RoomUse: String {
    case stairs
    case elevator
    case bathroom
    case classroom
    case laboratory
    case conferenceRoom
    case office
    case lounge
    case gym
    case foodAndDrink
}

struct IndoorShape: Identifiable {
    let id: String
    let kind: IndoorKind
    let shape: MKShape
    let use: RoomUse?
    let geometryId: String
}

enum IndoorLabelKind {
    case room
    case area
    case bathroom
    case classroom
    case laboratory
    case conferenceRoom
    case office
    case lounge
    case gym
    case foodAndDrink
    case stairs
    case elevator
    case annotation
}

struct IndoorLabel: Identifiable {
    let id: String
    let text: String
    let coordinate: CLLocationCoordinate2D
    let kind: IndoorLabelKind
}

struct IndoorLocation: Identifiable {
    let id: String
    let name: String
    let description: String?
    let categories: [String]
    let openingHours: [IndoorOpeningHours]
    let website: IndoorWebsite?
    let coordinate: CLLocationCoordinate2D
    let use: RoomUse?
    let labelKind: IndoorLabelKind
    let isArea: Bool
}

struct IndoorOpeningHours: Identifiable {
    let id = UUID()
    let days: [String]
    let opens: String
    let closes: String
}

struct IndoorWebsite {
    let label: String?
    let url: String?
}

struct IndoorNode: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}

struct IndoorDataset {
    let buildings: [IndoorBuilding]
    let shapesByFloor: [String: [IndoorShape]]
    let labelsByFloor: [String: [IndoorLabel]]
    let locationsByFloor: [String: [IndoorLocation]]
    let nodesByFloor: [String: [IndoorNode]]

    static let empty = IndoorDataset(buildings: [],
                                     shapesByFloor: [:],
                                     labelsByFloor: [:],
                                     locationsByFloor: [:],
                                     nodesByFloor: [:])
}

enum IndoorDataLoader {
    static func loadCampusIndoorData() -> IndoorDataset {
        let folderName = "CampusIndoorData"
        guard let baseURL = Bundle.main.resourceURL?.appendingPathComponent(folderName) else {
            return .empty
        }

        let floorStacks = loadFloorStacks(from: baseURL)
        let referencedFloorIds = Set(floorStacks.flatMap { $0.floors })

        let decoder = MKGeoJSONDecoder()
        var floorMetadata: [String: IndoorFloor] = [:]
        var shapesByFloor: [String: [IndoorShape]] = [:]
        let roomUsesByGeometryId = loadRoomUses(from: baseURL)

        let floorsURL = baseURL.appendingPathComponent("floors.geojson")
        if let data = try? Data(contentsOf: floorsURL),
           let objects = try? decoder.decode(data) {
            for obj in objects {
                guard let feature = obj as? MKGeoJSONFeature,
                      let floor = parseFloorFeature(feature) else { continue }

                guard referencedFloorIds.isEmpty || referencedFloorIds.contains(floor.id) else { continue }

                floorMetadata[floor.id] = floor
                var shapes = shapesByFloor[floor.id] ?? []
                for (index, geometry) in feature.geometry.enumerated() {
                    appendShapes(from: geometry,
                                 baseId: "\(floor.id)-outline-\(index)",
                                 geometryId: floor.id,
                                 kind: .outline,
                                 use: nil,
                                 into: &shapes)
                }
                shapesByFloor[floor.id] = shapes
            }
        }

        let targetFloorIds: [String]
        if !referencedFloorIds.isEmpty {
            targetFloorIds = Array(referencedFloorIds)
        } else if !floorMetadata.isEmpty {
            targetFloorIds = Array(floorMetadata.keys)
        } else {
            targetFloorIds = []
        }

        if !targetFloorIds.isEmpty {
            loadGeometry(from: baseURL,
                         floorIds: targetFloorIds,
                         decoder: decoder,
                         roomUsesByGeometryId: roomUsesByGeometryId,
                         shapesByFloor: &shapesByFloor)
        }

        let geometryCentersByFloor = buildGeometryCenters(from: shapesByFloor)
        let geometryKindsByFloor = buildGeometryKinds(from: shapesByFloor)
        let labelsByFloor = loadLabels(from: baseURL,
                                       geometryCentersByFloor: geometryCentersByFloor,
                                       geometryKindsByFloor: geometryKindsByFloor,
                                       roomUsesByGeometryId: roomUsesByGeometryId)
        let locationsByFloor = loadLocations(from: baseURL,
                                             geometryCentersByFloor: geometryCentersByFloor,
                                             geometryKindsByFloor: geometryKindsByFloor,
                                             roomUsesByGeometryId: roomUsesByGeometryId)
        let nodesByFloor = loadNodes(from: baseURL, decoder: decoder)

        var buildings: [IndoorBuilding] = []
        if !floorStacks.isEmpty {
            buildings = floorStacks.map { stack in
                let floors = stack.floors.map { floorId in
                    floorMetadata[floorId] ?? IndoorFloor(id: floorId, name: floorId, elevation: 0)
                }
                let sortedFloors = floors.sorted { $0.elevation < $1.elevation }
                let defaultFloor = stack.defaultFloor ?? sortedFloors.first?.id ?? ""
                let name = stack.details?.name ?? "Building"
                return IndoorBuilding(id: stack.id,
                                      name: name,
                                      floors: sortedFloors,
                                      defaultFloorId: defaultFloor)
            }
            buildings.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else if !floorMetadata.isEmpty {
            let floors = floorMetadata.values.sorted { $0.elevation < $1.elevation }
            buildings = [IndoorBuilding(id: "all",
                                        name: "All Buildings",
                                        floors: floors,
                                        defaultFloorId: floors.first?.id ?? "")]
        }

        if !buildings.isEmpty {
            buildings.insert(IndoorBuilding(id: "overview",
                                            name: "Overview",
                                            floors: [],
                                            defaultFloorId: ""),
                             at: 0)
        }

        return IndoorDataset(buildings: buildings,
                             shapesByFloor: shapesByFloor,
                             labelsByFloor: labelsByFloor,
                             locationsByFloor: locationsByFloor,
                             nodesByFloor: nodesByFloor)
    }

    private static func loadFloorStacks(from baseURL: URL) -> [FloorStackDTO] {
        let url = baseURL.appendingPathComponent("floor-stacks.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([FloorStackDTO].self, from: data)) ?? []
    }

    private static func loadGeometry(from baseURL: URL,
                                     floorIds: [String],
                                     decoder: MKGeoJSONDecoder,
                                     roomUsesByGeometryId: [String: RoomUse],
                                     shapesByFloor: inout [String: [IndoorShape]]) {
        let geometryBase = baseURL.appendingPathComponent("geometry")
        let kindsBase = baseURL.appendingPathComponent("kinds")
        let entranceBase = baseURL.appendingPathComponent("entrance-aesthetic")

        for floorId in floorIds {
            let geometryURL = geometryBase.appendingPathComponent("\(floorId).geojson")
            guard let data = try? Data(contentsOf: geometryURL),
                  let objects = try? decoder.decode(data) else {
                continue
            }

            let kindMap = loadKindMap(from: kindsBase.appendingPathComponent("\(floorId).json"))
            let doorIds = loadEntranceIds(from: entranceBase.appendingPathComponent("\(floorId).json"))

            var shapes = shapesByFloor[floorId] ?? []

            for obj in objects {
                guard let feature = obj as? MKGeoJSONFeature,
                      let featureId = parseFeatureId(feature) else { continue }

                let kind: IndoorKind
                if doorIds.contains(featureId) {
                    kind = .door
                } else {
                    kind = IndoorKind(kind: kindMap[featureId])
                }
                let use = roomUsesByGeometryId[featureId]

                for (index, geometry) in feature.geometry.enumerated() {
                    appendShapes(from: geometry,
                                 baseId: "\(featureId)-\(index)",
                                 geometryId: featureId,
                                 kind: kind,
                                 use: use,
                                 into: &shapes)
                }
            }

            shapesByFloor[floorId] = shapes
        }
    }

    private static func loadKindMap(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data),
              let dict = json as? [String: String] else {
            return [:]
        }
        return dict
    }

    private static func loadEntranceIds(from url: URL) -> Set<String> {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([EntranceAestheticDTO].self, from: data) else {
            return []
        }
        return Set(entries.map(\.geometryId))
    }

    private static func appendShapes(from geometry: MKShape,
                                     baseId: String,
                                     geometryId: String,
                                     kind: IndoorKind,
                                     use: RoomUse?,
                                     into shapes: inout [IndoorShape]) {
        if let multiPolygon = geometry as? MKMultiPolygon {
            for (index, polygon) in multiPolygon.polygons.enumerated() {
                shapes.append(IndoorShape(id: "\(baseId)-mp\(index)",
                                          kind: kind,
                                          shape: polygon,
                                          use: use,
                                          geometryId: geometryId))
            }
            return
        }

        if let multiPolyline = geometry as? MKMultiPolyline {
            for (index, polyline) in multiPolyline.polylines.enumerated() {
                shapes.append(IndoorShape(id: "\(baseId)-ml\(index)",
                                          kind: kind,
                                          shape: polyline,
                                          use: use,
                                          geometryId: geometryId))
            }
            return
        }

        shapes.append(IndoorShape(id: baseId,
                                  kind: kind,
                                  shape: geometry,
                                  use: use,
                                  geometryId: geometryId))
    }

    private static func parseFloorFeature(_ feature: MKGeoJSONFeature) -> IndoorFloor? {
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

    private static func parseFeatureId(_ feature: MKGeoJSONFeature) -> String? {
        guard let data = feature.properties,
              let props = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return props["id"] as? String
    }

    private static func buildGeometryCenters(from shapesByFloor: [String: [IndoorShape]]) -> [String: [String: CLLocationCoordinate2D]] {
        var centersByFloor: [String: [String: CLLocationCoordinate2D]] = [:]

        for (floorId, shapes) in shapesByFloor {
            var centers: [String: CLLocationCoordinate2D] = [:]
            for shape in shapes {
                if centers[shape.geometryId] != nil { continue }
                if let center = geometryCenter(for: shape.shape) {
                    centers[shape.geometryId] = center
                }
            }
            centersByFloor[floorId] = centers
        }

        return centersByFloor
    }

    private static func buildGeometryKinds(from shapesByFloor: [String: [IndoorShape]]) -> [String: [String: IndoorKind]] {
        var kindsByFloor: [String: [String: IndoorKind]] = [:]
        for (floorId, shapes) in shapesByFloor {
            var kinds: [String: IndoorKind] = [:]
            for shape in shapes {
                if kinds[shape.geometryId] == nil || kinds[shape.geometryId] == .unknown {
                    kinds[shape.geometryId] = shape.kind
                }
            }
            kindsByFloor[floorId] = kinds
        }
        return kindsByFloor
    }

    private static func geometryCenter(for shape: MKShape) -> CLLocationCoordinate2D? {
        if let point = shape as? MKPointAnnotation {
            return point.coordinate
        }
        if let polygon = shape as? MKPolygon {
            return mapRectCenter(polygon.boundingMapRect)
        }
        if let polyline = shape as? MKPolyline {
            return mapRectCenter(polyline.boundingMapRect)
        }
        if let multiPolygon = shape as? MKMultiPolygon {
            return mapRectCenter(unionRects(multiPolygon.polygons.map(\.boundingMapRect)))
        }
        if let multiPolyline = shape as? MKMultiPolyline {
            return mapRectCenter(unionRects(multiPolyline.polylines.map(\.boundingMapRect)))
        }
        return nil
    }

    private static func unionRects(_ rects: [MKMapRect]) -> MKMapRect? {
        var combined: MKMapRect?
        for rect in rects {
            combined = combined.map { $0.union(rect) } ?? rect
        }
        return combined
    }

    private static func mapRectCenter(_ rect: MKMapRect?) -> CLLocationCoordinate2D? {
        guard let rect else { return nil }
        let center = MKMapPoint(x: rect.midX, y: rect.midY)
        return center.coordinate
    }

    private static func loadRoomUses(from baseURL: URL) -> [String: RoomUse] {
        let connectionsURL = baseURL.appendingPathComponent("connections.json")
        let categoriesURL = baseURL.appendingPathComponent("location-categories.json")
        let locationsURL = baseURL.appendingPathComponent("locations.json")

        var uses: [String: RoomUse] = [:]

        let connectionUses = loadConnectionUses(from: connectionsURL)
        for (geometryId, use) in connectionUses {
            uses[geometryId] = mergeRoomUse(existing: uses[geometryId], new: use)
        }

        let categoryNames = loadCategoryNames(from: categoriesURL)
        let locationUses = loadLocationUses(from: locationsURL, categoryNames: categoryNames)
        for (geometryId, use) in locationUses {
            uses[geometryId] = mergeRoomUse(existing: uses[geometryId], new: use)
        }

        return uses
    }

    private static func loadLabels(from baseURL: URL,
                                   geometryCentersByFloor: [String: [String: CLLocationCoordinate2D]],
                                   geometryKindsByFloor: [String: [String: IndoorKind]],
                                   roomUsesByGeometryId: [String: RoomUse]) -> [String: [IndoorLabel]] {
        var labelsByFloor: [String: [IndoorLabel]] = [:]

        let categoriesURL = baseURL.appendingPathComponent("location-categories.json")
        let locationsURL = baseURL.appendingPathComponent("locations.json")
        let connectionsURL = baseURL.appendingPathComponent("connections.json")
        let annotationSymbolsURL = baseURL.appendingPathComponent("annotation-symbols.json")
        let annotationsBase = baseURL.appendingPathComponent("annotations")

        let categoryNames = loadCategoryNames(from: categoriesURL)
        let locationLabels = loadLocationLabels(from: locationsURL,
                                                categoryNames: categoryNames,
                                                geometryCentersByFloor: geometryCentersByFloor,
                                                geometryKindsByFloor: geometryKindsByFloor,
                                                roomUsesByGeometryId: roomUsesByGeometryId)
        mergeLabels(locationLabels, into: &labelsByFloor)

        let connectionLabels = loadConnectionLabels(from: connectionsURL,
                                                    geometryCentersByFloor: geometryCentersByFloor)
        mergeLabels(connectionLabels, into: &labelsByFloor)

        let symbolNames = loadAnnotationSymbols(from: annotationSymbolsURL)
        let annotationLabels = loadAnnotationLabels(from: annotationsBase,
                                                    symbolNames: symbolNames,
                                                    geometryCentersByFloor: geometryCentersByFloor)
        mergeLabels(annotationLabels, into: &labelsByFloor)

        return labelsByFloor
    }

    private static func loadLocations(from baseURL: URL,
                                      geometryCentersByFloor: [String: [String: CLLocationCoordinate2D]],
                                      geometryKindsByFloor: [String: [String: IndoorKind]],
                                      roomUsesByGeometryId: [String: RoomUse]) -> [String: [IndoorLocation]] {
        let categoriesURL = baseURL.appendingPathComponent("location-categories.json")
        let locationsURL = baseURL.appendingPathComponent("locations.json")
        let connectionsURL = baseURL.appendingPathComponent("connections.json")

        let categoryNames = loadCategoryNames(from: categoriesURL)
        guard let data = try? Data(contentsOf: locationsURL),
              let locations = try? JSONDecoder().decode([LocationDTO].self, from: data) else {
            return [:]
        }

        var locationsByFloor: [String: [IndoorLocation]] = [:]
        for location in locations {
            let names = location.categories.compactMap { categoryNames[$0] }
            let inferredUse = classifyRoomUse(categoryNames: names, locationName: location.details?.name)

            for anchor in location.geometryAnchors {
                guard let centers = geometryCentersByFloor[anchor.floorId],
                      let coordinate = centers[anchor.geometryId] else { continue }

                let use = roomUsesByGeometryId[anchor.geometryId] ?? inferredUse
                let geometryKind = geometryKindsByFloor[anchor.floorId]?[anchor.geometryId]
                let labelKind = labelKind(for: use,
                                          name: location.details?.name,
                                          geometryKind: geometryKind)
                let isArea = labelKind == .area
                let hours = (location.openingHours ?? []).map {
                    IndoorOpeningHours(days: $0.dayOfWeek.values,
                                       opens: $0.opens,
                                       closes: $0.closes)
                }
                let website = location.website.map { IndoorWebsite(label: $0.label, url: $0.url) }
                let indoorLocation = IndoorLocation(
                    id: "\(location.id)-\(anchor.geometryId)",
                    name: location.details?.name ?? "Location",
                    description: location.details?.description,
                    categories: names,
                    openingHours: hours,
                    website: website,
                    coordinate: coordinate,
                    use: use,
                    labelKind: labelKind,
                    isArea: isArea
                )
                locationsByFloor[anchor.floorId, default: []].append(indoorLocation)
            }
        }

        mergeLocations(loadConnectionLocations(from: connectionsURL,
                                               geometryCentersByFloor: geometryCentersByFloor),
                       into: &locationsByFloor)

        return locationsByFloor
    }

    private static func loadConnectionLocations(from url: URL,
                                                geometryCentersByFloor: [String: [String: CLLocationCoordinate2D]]) -> [String: [IndoorLocation]] {
        guard let data = try? Data(contentsOf: url),
              let connections = try? JSONDecoder().decode([ConnectionDTO].self, from: data) else {
            return [:]
        }

        var locationsByFloor: [String: [IndoorLocation]] = [:]
        var seen = Set<String>()
        for connection in connections {
            let use: RoomUse?
            switch connection.type.lowercased() {
            case "stairs": use = .stairs
            case "elevator": use = .elevator
            default: use = nil
            }
            guard let use else { continue }

            let endpoints = connection.entrances + (connection.exits ?? [])
            for endpoint in endpoints {
                guard let floorId = endpoint.floorId,
                      let centers = geometryCentersByFloor[floorId],
                      let coordinate = centers[endpoint.geometryId] else { continue }

                let key = "\(endpoint.geometryId)-\(use)"
                if seen.contains(key) { continue }
                seen.insert(key)

                let name = use == .stairs ? "Stairs" : "Elevator"
                let location = IndoorLocation(
                    id: "connection-\(connection.id)-\(endpoint.geometryId)",
                    name: name,
                    description: nil,
                    categories: [name],
                    openingHours: [],
                    website: nil,
                    coordinate: coordinate,
                    use: use,
                    labelKind: use == .stairs ? .stairs : .elevator,
                    isArea: false
                )
                locationsByFloor[floorId, default: []].append(location)
            }
        }

        return locationsByFloor
    }

    private static func mergeLocations(_ incoming: [String: [IndoorLocation]],
                                       into target: inout [String: [IndoorLocation]]) {
        for (floorId, locations) in incoming {
            target[floorId, default: []].append(contentsOf: locations)
        }
    }

    private static func mergeLabels(_ incoming: [String: [IndoorLabel]],
                                    into target: inout [String: [IndoorLabel]]) {
        for (floorId, labels) in incoming {
            target[floorId, default: []].append(contentsOf: labels)
        }
    }

    private static func loadLocationLabels(from url: URL,
                                           categoryNames: [String: String],
                                           geometryCentersByFloor: [String: [String: CLLocationCoordinate2D]],
                                           geometryKindsByFloor: [String: [String: IndoorKind]],
                                           roomUsesByGeometryId: [String: RoomUse]) -> [String: [IndoorLabel]] {
        guard let data = try? Data(contentsOf: url),
              let locations = try? JSONDecoder().decode([LocationDTO].self, from: data) else {
            return [:]
        }

        var labelsByFloor: [String: [IndoorLabel]] = [:]
        for location in locations {
            let inferredUse = classifyRoomUse(categoryNames: location.categories.compactMap { categoryNames[$0] },
                                              locationName: location.details?.name)

            for anchor in location.geometryAnchors {
                let use = roomUsesByGeometryId[anchor.geometryId] ?? inferredUse
                let name = location.details?.name
                let geometryKind = geometryKindsByFloor[anchor.floorId]?[anchor.geometryId]
                let kind = labelKind(for: use, name: name, geometryKind: geometryKind)
                guard let centers = geometryCentersByFloor[anchor.floorId],
                      let coordinate = centers[anchor.geometryId] else { continue }
                let text = name ?? "Location"
                let label = IndoorLabel(id: "\(location.id)-\(anchor.geometryId)",
                                        text: text,
                                        coordinate: coordinate,
                                        kind: kind)
                labelsByFloor[anchor.floorId, default: []].append(label)
            }
        }

        return labelsByFloor
    }

    private static func loadConnectionLabels(from url: URL,
                                             geometryCentersByFloor: [String: [String: CLLocationCoordinate2D]]) -> [String: [IndoorLabel]] {
        guard let data = try? Data(contentsOf: url),
              let connections = try? JSONDecoder().decode([ConnectionDTO].self, from: data) else {
            return [:]
        }

        var labelsByFloor: [String: [IndoorLabel]] = [:]
        for connection in connections {
            let use: RoomUse?
            switch connection.type.lowercased() {
            case "stairs": use = .stairs
            case "elevator": use = .elevator
            default: use = nil
            }
            guard let use else { continue }

            let endpoints = connection.entrances + (connection.exits ?? [])
            for endpoint in endpoints {
                guard let floorId = endpoint.floorId,
                      let centers = geometryCentersByFloor[floorId],
                      let coordinate = centers[endpoint.geometryId] else { continue }
                let text = use == .stairs ? "Stairs" : "Elevator"
                let label = IndoorLabel(id: "\(connection.id)-\(endpoint.geometryId)",
                                        text: text,
                                        coordinate: coordinate,
                                        kind: use == .stairs ? .stairs : .elevator)
                labelsByFloor[floorId, default: []].append(label)
            }
        }

        return labelsByFloor
    }

    private static func loadAnnotationSymbols(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let symbols = try? JSONDecoder().decode([String: AnnotationSymbolDTO].self, from: data) else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in symbols {
            if let name = value.name {
                result[key] = name
            }
        }
        return result
    }

    private static func loadAnnotationLabels(from baseURL: URL,
                                             symbolNames: [String: String],
                                             geometryCentersByFloor: [String: [String: CLLocationCoordinate2D]]) -> [String: [IndoorLabel]] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: baseURL,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles]) else {
            return [:]
        }

        var labelsByFloor: [String: [IndoorLabel]] = [:]
        for fileURL in files where fileURL.pathExtension.lowercased() == "json" {
            let floorId = fileURL.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: fileURL),
                  let annotations = try? JSONDecoder().decode([AnnotationDTO].self, from: data) else {
                continue
            }

            for annotation in annotations {
                guard let centers = geometryCentersByFloor[floorId],
                      let coordinate = centers[annotation.geometryId] else { continue }
                let text = symbolNames[annotation.symbolKey] ?? annotation.symbolKey
                let label = IndoorLabel(id: annotation.id,
                                        text: text,
                                        coordinate: coordinate,
                                        kind: .annotation)
                labelsByFloor[floorId, default: []].append(label)
            }
        }

        return labelsByFloor
    }

    private static func loadNodes(from baseURL: URL, decoder: MKGeoJSONDecoder) -> [String: [IndoorNode]] {
        let nodesBase = baseURL.appendingPathComponent("nodes")
        guard let files = try? FileManager.default.contentsOfDirectory(at: nodesBase,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles]) else {
            return [:]
        }

        var nodesByFloor: [String: [IndoorNode]] = [:]
        for fileURL in files where fileURL.pathExtension.lowercased() == "geojson" {
            let floorId = fileURL.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: fileURL),
                  let objects = try? decoder.decode(data) else { continue }

            for obj in objects {
                guard let feature = obj as? MKGeoJSONFeature else { continue }
                let id = parseFeatureId(feature) ?? UUID().uuidString
                for geometry in feature.geometry {
                    if let point = geometry as? MKPointAnnotation {
                        nodesByFloor[floorId, default: []].append(
                            IndoorNode(id: "\(id)-\(floorId)", coordinate: point.coordinate)
                        )
                    }
                }
            }
        }
        return nodesByFloor
    }

    private static func labelKind(for use: RoomUse?, name: String?, geometryKind: IndoorKind?) -> IndoorLabelKind {
        switch use {
        case .bathroom: return .bathroom
        case .classroom: return .classroom
        case .laboratory: return .laboratory
        case .conferenceRoom: return .conferenceRoom
        case .office: return .office
        case .lounge: return .lounge
        case .gym: return .gym
        case .foodAndDrink: return .foodAndDrink
        case .stairs: return .stairs
        case .elevator: return .elevator
        case .none:
            if geometryKind == .area || geometryKind == .hallway {
                return .area
            }
            if geometryKind == .room || geometryKind == .object {
                return .room
            }
            let text = (name ?? "").lowercased()
            if text.rangeOfCharacter(from: .decimalDigits) == nil {
                return .area
            }
            return .room
        }
    }

    private static func loadConnectionUses(from url: URL) -> [String: RoomUse] {
        guard let data = try? Data(contentsOf: url),
              let connections = try? JSONDecoder().decode([ConnectionDTO].self, from: data) else {
            return [:]
        }

        var uses: [String: RoomUse] = [:]
        for connection in connections {
            let use: RoomUse?
            switch connection.type.lowercased() {
            case "stairs": use = .stairs
            case "elevator": use = .elevator
            default: use = nil
            }
            guard let use else { continue }
            let endpoints = connection.entrances + (connection.exits ?? [])
            for endpoint in endpoints {
                uses[endpoint.geometryId] = mergeRoomUse(existing: uses[endpoint.geometryId], new: use)
            }
        }
        return uses
    }

    private static func loadCategoryNames(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([CategoryDTO].self, from: data) else {
            return [:]
        }
        var names: [String: String] = [:]
        for category in categories {
            if let name = category.details?.name {
                names[category.id] = name
            }
        }
        return names
    }

    private static func loadLocationUses(from url: URL,
                                         categoryNames: [String: String]) -> [String: RoomUse] {
        guard let data = try? Data(contentsOf: url),
              let locations = try? JSONDecoder().decode([LocationDTO].self, from: data) else {
            return [:]
        }

        var uses: [String: RoomUse] = [:]
        for location in locations {
            let names = location.categories.compactMap { categoryNames[$0] }
            let use = classifyRoomUse(categoryNames: names, locationName: location.details?.name)
            guard let use else { continue }
            for anchor in location.geometryAnchors {
                uses[anchor.geometryId] = mergeRoomUse(existing: uses[anchor.geometryId], new: use)
            }
        }
        return uses
    }

    private static func classifyRoomUse(categoryNames: [String], locationName: String?) -> RoomUse? {
        let combined = (categoryNames + [locationName]).compactMap { $0 }.joined(separator: " ").lowercased()

        if combined.contains("restroom") || combined.contains("bathroom") || combined.contains("toilet") {
            return .bathroom
        }
        if combined.contains("laboratory") || combined.contains("lab") {
            return .laboratory
        }
        if combined.contains("conference") || combined.contains("meeting room") {
            return .conferenceRoom
        }
        if combined.contains("classroom") {
            return .classroom
        }
        if combined.contains("office") {
            return .office
        }
        if combined.contains("lounge") {
            return .lounge
        }
        if combined.contains("gym") || combined.contains("fitness") {
            return .gym
        }
        if combined.contains("cafe") || combined.contains("food") || combined.contains("dining") || combined.contains("coffee") {
            return .foodAndDrink
        }

        return nil
    }

    private static func mergeRoomUse(existing: RoomUse?, new: RoomUse) -> RoomUse {
        guard let existing else { return new }
        return roomUsePriority(new) > roomUsePriority(existing) ? new : existing
    }

    private static func roomUsePriority(_ use: RoomUse) -> Int {
        switch use {
        case .elevator: return 9
        case .stairs: return 8
        case .bathroom: return 7
        case .laboratory: return 6
        case .conferenceRoom: return 5
        case .classroom: return 4
        case .office: return 3
        case .gym: return 2
        case .foodAndDrink: return 2
        case .lounge: return 1
        }
    }
}

private struct FloorStackDTO: Decodable {
    struct Details: Decodable {
        let name: String?
    }

    let id: String
    let floors: [String]
    let defaultFloor: String?
    let details: Details?
}

private struct EntranceAestheticDTO: Decodable {
    let geometryId: String
    let kind: String?
}

private struct ConnectionDTO: Decodable {
    let id: String
    let type: String
    let entrances: [ConnectionEndpointDTO]
    let exits: [ConnectionEndpointDTO]?
}

private struct ConnectionEndpointDTO: Decodable {
    let geometryId: String
    let floorId: String?
}

private struct CategoryDTO: Decodable {
    let id: String
    let details: CategoryDetailsDTO?
}

private struct CategoryDetailsDTO: Decodable {
    let name: String?
}

private struct LocationDTO: Decodable {
    let id: String
    let categories: [String]
    let geometryAnchors: [LocationAnchorDTO]
    let details: LocationDetailsDTO?
    let openingHours: [OpeningHoursDTO]?
    let website: WebsiteDTO?
}

private struct LocationAnchorDTO: Decodable {
    let geometryId: String
    let floorId: String
}

private struct LocationDetailsDTO: Decodable {
    let name: String?
    let description: String?
}

private struct OpeningHoursDTO: Decodable {
    let opens: String
    let closes: String
    let dayOfWeek: DayOfWeekDTO
}

private enum DayOfWeekDTO: Decodable {
    case single(String)
    case multiple([String])

    var values: [String] {
        switch self {
        case .single(let value): return [value]
        case .multiple(let values): return values
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            self = .single(single)
        } else if let multiple = try? container.decode([String].self) {
            self = .multiple(multiple)
        } else {
            self = .multiple([])
        }
    }
}

private struct WebsiteDTO: Decodable {
    let label: String?
    let url: String?
}

private struct AnnotationDTO: Decodable {
    let id: String
    let geometryId: String
    let symbolKey: String
}

private struct AnnotationSymbolDTO: Decodable {
    let name: String?
}
