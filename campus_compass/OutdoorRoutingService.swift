//
//  OutdoorRoutingService.swift
//  Campus Compass
//
//  Created by Codex on 3/29/26.
//

import Foundation
import CoreLocation
import MapKit

struct OutdoorRouteCoordinator {
    private let graphRouter: CampusGraphRouter
    private let appleRouter = AppleDirectionsRouter()

    init(dataset: OutdoorGraphDataset) {
        self.graphRouter = CampusGraphRouter(dataset: dataset)
    }

    func route(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D
    ) async throws -> NavigationRoute {
        if let graphRoute = graphRouter.route(
            from: origin,
            destinationName: destinationName,
            destinationCoordinate: destinationCoordinate
        ) {
            return graphRoute
        }

        return try await appleRouter.route(
            from: origin,
            destinationName: destinationName,
            destinationCoordinate: destinationCoordinate
        )
    }
}

struct CampusGraphRouter {
    private let dataset: OutdoorGraphDataset
    private let nodesByID: [String: OutdoorGraphNode]
    private let nearestNodeThreshold: CLLocationDistance = 150
    private let arrivalSpeedMetersPerSecond: CLLocationDistance = 1.4

    init(dataset: OutdoorGraphDataset) {
        self.dataset = dataset
        self.nodesByID = Dictionary(uniqueKeysWithValues: dataset.nodes.map { ($0.id, $0) })
    }

    func route(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D
    ) -> NavigationRoute? {
        guard
            !dataset.nodes.isEmpty,
            !dataset.edges.isEmpty,
            let anchor = anchor(for: destinationName),
            let destinationNode = nodesByID[anchor.anchorNodeID],
            let originNode = nearestNode(to: origin)
        else {
            return nil
        }

        let originDistance = distance(from: origin, to: originNode.coordinate)
        let destinationDistance = distance(from: destinationNode.coordinate, to: destinationCoordinate)

        guard originDistance <= nearestNodeThreshold else {
            return nil
        }

        guard let pathNodeIDs = shortestPath(from: originNode.id, to: destinationNode.id) else {
            return nil
        }

        let pathNodes = pathNodeIDs.compactMap { nodesByID[$0] }
        guard !pathNodes.isEmpty else { return nil }

        var coordinates: [CLLocationCoordinate2D] = [origin]
        for node in pathNodes {
            if !sameCoordinate(node.coordinate, coordinates.last) {
                coordinates.append(node.coordinate)
            }
        }
        if !sameCoordinate(destinationCoordinate, coordinates.last) {
            coordinates.append(destinationCoordinate)
        }

        let pathDistance = edgeDistance(for: pathNodeIDs)
        let totalDistance = originDistance + pathDistance + destinationDistance

        var steps: [NavigationStep] = []
        if originDistance > 8 {
            steps.append(
                NavigationStep(
                    instruction: "Head to \(destinationNodeName(pathNodes.first, fallback: "campus path"))",
                    distance: originDistance
                )
            )
        }

        for pair in zip(pathNodes, pathNodes.dropFirst()) {
            let segmentDistance = edgeDistance(from: pair.0.id, to: pair.1.id)
            steps.append(
                NavigationStep(
                    instruction: "Continue to \(destinationNodeName(pair.1, fallback: destinationName))",
                    distance: segmentDistance
                )
            )
        }

        if destinationDistance > 8 {
            steps.append(
                NavigationStep(
                    instruction: "Arrive at \(destinationName)",
                    distance: destinationDistance
                )
            )
        }

        if steps.isEmpty {
            steps = [
                NavigationStep(
                    instruction: "Proceed to \(destinationName)",
                    distance: totalDistance
                )
            ]
        }

        return NavigationRoute(
            source: .campusGraph,
            coordinates: coordinates,
            steps: steps,
            distance: totalDistance,
            expectedTravelTime: totalDistance / arrivalSpeedMetersPerSecond,
            destinationName: destinationName
        )
    }

    private func anchor(for buildingName: String) -> OutdoorBuildingAnchor? {
        let normalized = normalize(buildingName)
        return dataset.anchors.first { normalize($0.buildingName) == normalized }
    }

    private func nearestNode(to coordinate: CLLocationCoordinate2D) -> OutdoorGraphNode? {
        dataset.nodes.min { lhs, rhs in
            distance(from: coordinate, to: lhs.coordinate) < distance(from: coordinate, to: rhs.coordinate)
        }
    }

    private func shortestPath(from sourceID: String, to destinationID: String) -> [String]? {
        var distances: [String: Double] = [sourceID: 0]
        var previous: [String: String] = [:]
        var unvisited = Set(nodesByID.keys)

        while !unvisited.isEmpty {
            guard let current = unvisited.min(by: { (distances[$0] ?? .infinity) < (distances[$1] ?? .infinity) }) else {
                break
            }

            if current == destinationID {
                break
            }

            unvisited.remove(current)
            let currentDistance = distances[current] ?? .infinity
            guard currentDistance.isFinite else { break }

            for neighbor in neighbors(of: current) where unvisited.contains(neighbor.nodeID) {
                let candidate = currentDistance + neighbor.weight
                if candidate < (distances[neighbor.nodeID] ?? .infinity) {
                    distances[neighbor.nodeID] = candidate
                    previous[neighbor.nodeID] = current
                }
            }
        }

        guard distances[destinationID] != nil else { return nil }

        var path = [destinationID]
        var current = destinationID
        while current != sourceID {
            guard let prev = previous[current] else { return nil }
            current = prev
            path.append(current)
        }

        return path.reversed()
    }

    private func neighbors(of nodeID: String) -> [(nodeID: String, weight: Double)] {
        var results: [(String, Double)] = []
        for edge in dataset.edges {
            let weight = edge.distance + edge.penalty
            if edge.fromNodeID == nodeID {
                results.append((edge.toNodeID, weight))
            }
            if edge.bidirectional && edge.toNodeID == nodeID {
                results.append((edge.fromNodeID, weight))
            }
        }
        return results
    }

    private func edgeDistance(for nodeIDs: [String]) -> CLLocationDistance {
        zip(nodeIDs, nodeIDs.dropFirst()).reduce(0) { partialResult, pair in
            partialResult + edgeDistance(from: pair.0, to: pair.1)
        }
    }

    private func edgeDistance(from fromNodeID: String, to toNodeID: String) -> CLLocationDistance {
        if let edge = dataset.edges.first(where: {
            ($0.fromNodeID == fromNodeID && $0.toNodeID == toNodeID)
                || ($0.bidirectional && $0.fromNodeID == toNodeID && $0.toNodeID == fromNodeID)
        }) {
            return edge.distance
        }

        guard let fromNode = nodesByID[fromNodeID], let toNode = nodesByID[toNodeID] else {
            return 0
        }
        return distance(from: fromNode.coordinate, to: toNode.coordinate)
    }

    private func destinationNodeName(_ node: OutdoorGraphNode?, fallback: String) -> String {
        guard let name = node?.name, !name.isEmpty else { return fallback }
        return name
    }

    private func distance(from lhs: CLLocationCoordinate2D, to rhs: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func sameCoordinate(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D?) -> Bool {
        guard let rhs else { return false }
        return abs(lhs.latitude - rhs.latitude) < 0.000001
            && abs(lhs.longitude - rhs.longitude) < 0.000001
    }
}

struct AppleDirectionsRouter {
    func route(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D
    ) async throws -> NavigationRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw NSError(
                domain: "CampusCompass.OutdoorRouting",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No walking route found."]
            )
        }

        return makeNavigationRoute(from: route, destinationName: destinationName)
    }

    private func makeNavigationRoute(from route: MKRoute, destinationName: String) -> NavigationRoute {
        let steps = route.steps
            .filter { !$0.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { step in
                NavigationStep(
                    instruction: step.instructions,
                    distance: step.distance
                )
            }

        let pointCount = route.polyline.pointCount
        let coordinates: [CLLocationCoordinate2D]
        if pointCount > 0 {
            var points = Array(
                repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                count: pointCount
            )
            route.polyline.getCoordinates(&points, range: NSRange(location: 0, length: pointCount))
            coordinates = points
        } else {
            coordinates = []
        }

        return NavigationRoute(
            source: .apple,
            coordinates: coordinates,
            steps: steps,
            distance: route.distance,
            expectedTravelTime: route.expectedTravelTime,
            destinationName: destinationName
        )
    }
}
