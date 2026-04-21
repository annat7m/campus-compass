import Foundation
import CoreLocation
import Combine

final class EntranceSnapManager: ObservableObject {
    @Published var snappedBuildingId: String? = nil
    @Published var snappedFloorId: String? = nil
    @Published var nearestNodeCoordinate: CLLocationCoordinate2D? = nil

    // Enter indoor mode when GPS is within 15m of an entrance
    private let enterThreshold: CLLocationDistance = 15
    // Exit indoor mode only when GPS is more than 25m from all entrances (hysteresis)
    private let exitThreshold: CLLocationDistance = 25

    func update(userLocation: CLLocation,
                entrances: [IndoorEntrance],
                nodesByFloor: [String: [IndoorNode]]) {
        if let buildingId = snappedBuildingId {
            // Already snapped — check if user has left the building
            let minDist = entrances
                .filter { $0.buildingId == buildingId }
                .map { CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
                .map { userLocation.distance(from: $0) }
                .min() ?? .greatestFiniteMagnitude

            if minDist > exitThreshold {
                snappedBuildingId = nil
                snappedFloorId = nil
                nearestNodeCoordinate = nil
            } else if let floorId = snappedFloorId {
                nearestNodeCoordinate = nearestNode(to: userLocation.coordinate,
                                                    floorId: floorId,
                                                    nodesByFloor: nodesByFloor)
            }
        } else {
            // Not snapped — find the closest entrance within the enter threshold
            let hit = entrances
                .map { ($0, userLocation.distance(from: CLLocation(latitude: $0.coordinate.latitude,
                                                                    longitude: $0.coordinate.longitude))) }
                .filter { $0.1 < enterThreshold }
                .min(by: { $0.1 < $1.1 })

            if let (entrance, _) = hit {
                snappedBuildingId = entrance.buildingId
                snappedFloorId = entrance.floorId
                nearestNodeCoordinate = nearestNode(to: userLocation.coordinate,
                                                    floorId: entrance.floorId,
                                                    nodesByFloor: nodesByFloor)
            }
        }
    }

    private func nearestNode(to coordinate: CLLocationCoordinate2D,
                              floorId: String,
                              nodesByFloor: [String: [IndoorNode]]) -> CLLocationCoordinate2D? {
        guard let nodes = nodesByFloor[floorId], !nodes.isEmpty else { return nil }
        let ref = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return nodes
            .min(by: {
                ref.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) <
                ref.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
            })?.coordinate
    }
}
