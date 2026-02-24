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

struct IndoorDataset {
    let buildings: [IndoorBuilding]
    let featuresByFloor: [String: [MKGeoJSONFeature]]

    static let empty = IndoorDataset(buildings: [], featuresByFloor: [:])
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
        var featuresByFloor: [String: [MKGeoJSONFeature]] = [:]

        let floorsURL = baseURL.appendingPathComponent("floors.geojson")
        if let data = try? Data(contentsOf: floorsURL),
           let objects = try? decoder.decode(data) {
            for obj in objects {
                guard let feature = obj as? MKGeoJSONFeature,
                      let floor = parseFloorFeature(feature) else { continue }

                if referencedFloorIds.isEmpty || referencedFloorIds.contains(floor.id) {
                    floorMetadata[floor.id] = floor
                    featuresByFloor[floor.id, default: []].append(feature)
                }
            }
        }

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

        return IndoorDataset(buildings: buildings, featuresByFloor: featuresByFloor)
    }

    private static func loadFloorStacks(from baseURL: URL) -> [FloorStackDTO] {
        let url = baseURL.appendingPathComponent("floor-stacks.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([FloorStackDTO].self, from: data)) ?? []
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
