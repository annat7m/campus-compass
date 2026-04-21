//
//  RoomSearchStore.swift
//  campus_compass
//

import Foundation
import Combine

struct RoomSearchResult: Identifiable, Hashable {
    let id: String           // "\(locationId)-\(floorId)-\(geometryId)"
    let name: String         // e.g. "Strain 303"
    let buildingName: String // e.g. "Strain Hall"
    let buildingId: String   // floor stack id, e.g. "fs_6953fc..."
    let floorId: String      // e.g. "f_09746c..."
    let geometryId: String   // anchor geometry id for exact map selection
}

final class RoomSearchStore: ObservableObject {
    @Published var rooms: [RoomSearchResult] = []

    func load() async {
        // Free function — no actor context, safe to call from Task.detached
        let result = await Task.detached(priority: .utility) {
            loadRoomsFromBundle()
        }.value
        await MainActor.run { self.rooms = result }
    }
}

private func loadRoomsFromBundle() -> [RoomSearchResult] {
    let folder = "CampusIndoorData"
    guard let base = Bundle.main.resourceURL?.appendingPathComponent(folder) else { return [] }

    // Build floorId → (buildingId, buildingName) from floor-stacks.json
    let stacksURL = base.appendingPathComponent("floor-stacks.json")
    guard let stacksData = try? Data(contentsOf: stacksURL),
          let stacks = try? JSONDecoder().decode([RSSFloorStackDTO].self, from: stacksData) else {
        return []
    }
    var floorToBuilding: [String: (id: String, name: String)] = [:]
    for stack in stacks {
        let buildingName = stack.details?.name ?? "Unknown Building"
        for floorId in stack.floors {
            floorToBuilding[floorId] = (id: stack.id, name: buildingName)
        }
    }

    // Parse room names from locations.json
    let locationsURL = base.appendingPathComponent("locations.json")
    guard let locationsData = try? Data(contentsOf: locationsURL),
          let locations = try? JSONDecoder().decode([RSSLocationDTO].self, from: locationsData) else {
        return []
    }

    var results: [RoomSearchResult] = []
    var seen = Set<String>()
    for location in locations {
        guard let name = location.details?.name, !name.isEmpty else { continue }
        for anchor in location.geometryAnchors {
            guard let building = floorToBuilding[anchor.floorId] else { continue }
            let key = "\(location.id)-\(anchor.floorId)-\(anchor.geometryId)"
            if seen.contains(key) { continue }
            seen.insert(key)
            results.append(RoomSearchResult(
                id: key,
                name: name,
                buildingName: building.name,
                buildingId: building.id,
                floorId: anchor.floorId,
                geometryId: anchor.geometryId
            ))
            break // one result per location; first matching building anchor wins
        }
    }

    return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

// Minimal private DTOs — only the fields needed for search
private struct RSSFloorStackDTO: Decodable {
    struct Details: Decodable { let name: String? }
    let id: String
    let floors: [String]
    let details: Details?
}

private struct RSSLocationDTO: Decodable {
    let id: String
    let geometryAnchors: [RSSAnchorDTO]
    let details: RSSDetailsDTO?
}

private struct RSSAnchorDTO: Decodable {
    let geometryId: String
    let floorId: String
}

private struct RSSDetailsDTO: Decodable {
    let name: String?
}
