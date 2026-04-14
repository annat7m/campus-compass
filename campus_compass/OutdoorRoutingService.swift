//
//  OutdoorRoutingService.swift
//  Campus Compass
//
//  Created by Codex on 3/29/26.
//

import Foundation
import CoreLocation
import MapKit

enum OutdoorInitialRouteMode {
    case campusDirect
    case appleToGraphEntry
}

struct OutdoorRouteBootstrap {
    let mode: OutdoorInitialRouteMode
    let entryNode: OutdoorGraphNode
    let entryDistance: CLLocationDistance
}

struct OutdoorRouteCoordinator {
    private let graphRouter: CampusGraphRouter
    private let appleRouter = AppleDirectionsRouter()

    init(dataset: OutdoorGraphDataset) {
        self.graphRouter = CampusGraphRouter(dataset: dataset)
    }

    func bootstrap(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        preferredAnchorNodeID: String? = nil,
        requireAccessibleEntrances: Bool = false,
        appleTriggerDistance: CLLocationDistance = 40
    ) -> OutdoorRouteBootstrap? {
        guard let entry = graphRouter.entryNodeForRoute(
            from: origin,
            destinationName: destinationName,
            preferredAnchorNodeID: preferredAnchorNodeID,
            requireAccessibleEntrances: requireAccessibleEntrances
        ) else {
            return nil
        }

        let mode: OutdoorInitialRouteMode =
            entry.distanceFromOrigin > appleTriggerDistance ? .appleToGraphEntry : .campusDirect

        return OutdoorRouteBootstrap(
            mode: mode,
            entryNode: entry.node,
            entryDistance: entry.distanceFromOrigin
        )
    }

    func campusRoute(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D,
        preferredAnchorNodeID: String? = nil,
        requireAccessibleEntrances: Bool = false
    ) -> NavigationRoute? {
        graphRouter.route(
            from: origin,
            destinationName: destinationName,
            destinationCoordinate: destinationCoordinate,
            preferredAnchorNodeID: preferredAnchorNodeID,
            requireAccessibleEntrances: requireAccessibleEntrances
        )
    }

    func appleRoute(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D
    ) async throws -> NavigationRoute {
        try await appleRouter.route(
            from: origin,
            destinationName: destinationName,
            destinationCoordinate: destinationCoordinate
        )
    }

    func route(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D,
        preferredAnchorNodeID: String? = nil,
        requireAccessibleEntrances: Bool = false
    ) async throws -> NavigationRoute {
        if let graphRoute = graphRouter.route(
            from: origin,
            destinationName: destinationName,
            destinationCoordinate: destinationCoordinate,
            preferredAnchorNodeID: preferredAnchorNodeID,
            requireAccessibleEntrances: requireAccessibleEntrances
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
    struct GraphEntryResult {
        let node: OutdoorGraphNode
        let distanceFromOrigin: CLLocationDistance
    }

    private let dataset: OutdoorGraphDataset
    private let nodesByID: [String: OutdoorGraphNode]
    private let edgesByNodePair: [String: OutdoorGraphEdge]
    private let nearestNodeThreshold: CLLocationDistance = 150
    private let leadingEdgeJoinThreshold: CLLocationDistance = 30
    private let arrivalSpeedMetersPerSecond: CLLocationDistance = 1.4

    init(dataset: OutdoorGraphDataset) {
        self.dataset = dataset
        self.nodesByID = Dictionary(uniqueKeysWithValues: dataset.nodes.map { ($0.id, $0) })
        self.edgesByNodePair = Dictionary(
            uniqueKeysWithValues: dataset.edges.map { edge in
                ("\(edge.fromNodeID)->\(edge.toNodeID)", edge)
            }
        )
    }

    func route(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D,
        preferredAnchorNodeID: String? = nil,
        requireAccessibleEntrances: Bool = false
    ) -> NavigationRoute? {
        guard
            !dataset.nodes.isEmpty,
            !dataset.edges.isEmpty,
            let originNode = nearestNode(to: origin)
        else {
            return nil
        }

        let originDistance = distance(from: origin, to: originNode.coordinate)

        guard originDistance <= nearestNodeThreshold else {
            return nil
        }

        let candidateAnchors = anchors(
            for: destinationName,
            preferredAnchorNodeID: preferredAnchorNodeID,
            requireAccessibleEntrances: requireAccessibleEntrances
        )

        var bestPathNodeIDs: [String]?
        var bestDestinationNode: OutdoorGraphNode?
        var bestPathDistance: CLLocationDistance = .infinity

        for anchor in candidateAnchors {
            guard let destinationNode = nodesByID[anchor.anchorNodeID] else { continue }
            guard let candidatePath = shortestPath(from: originNode.id, to: destinationNode.id) else { continue }
            let candidateDistance = edgeDistance(for: candidatePath)
            if candidateDistance < bestPathDistance {
                bestPathDistance = candidateDistance
                bestPathNodeIDs = candidatePath
                bestDestinationNode = destinationNode
            }
        }

        guard
            let pathNodeIDs = bestPathNodeIDs,
            let destinationNode = bestDestinationNode
        else {
            return nil
        }

        let pathNodes = pathNodeIDs.compactMap { nodesByID[$0] }
        guard !pathNodes.isEmpty else { return nil }

        var coordinates: [CLLocationCoordinate2D] = []
        appendCoordinates(
            edgeCoordinates(for: pathNodeIDs, origin: origin),
            into: &coordinates
        )
        if !sameCoordinate(destinationNode.coordinate, coordinates.last) {
            coordinates.append(destinationNode.coordinate)
        }

        let pathDistance = edgeDistance(for: pathNodeIDs)
        let totalDistance = originDistance + pathDistance

        var steps: [NavigationStep] = []
        if originDistance > 8 {
            steps.append(
                NavigationStep(
                    instruction: "Head to \(destinationNodeName(pathNodes.first, fallback: "campus path"))",
                    distance: originDistance,
                    targetCoordinate: pathNodes.first?.coordinate
                )
            )
        }

        for pair in zip(pathNodes, pathNodes.dropFirst()) {
            let segmentDistance = edgeDistance(from: pair.0.id, to: pair.1.id)
            steps.append(
                NavigationStep(
                    instruction: "Continue to \(destinationNodeName(pair.1, fallback: destinationName))",
                    distance: segmentDistance,
                    targetCoordinate: pair.1.coordinate
                )
            )
        }

        if steps.isEmpty {
            steps = [
                NavigationStep(
                    instruction: "Proceed to \(destinationName)",
                    distance: totalDistance,
                    targetCoordinate: destinationCoordinate
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

    func entryNodeForRoute(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        preferredAnchorNodeID: String? = nil,
        requireAccessibleEntrances: Bool = false
    ) -> GraphEntryResult? {
        guard
            !dataset.nodes.isEmpty,
            !dataset.edges.isEmpty,
            let destinationNode = destinationNodeForBootstrap(
                from: origin,
                destinationName: destinationName,
                preferredAnchorNodeID: preferredAnchorNodeID,
                requireAccessibleEntrances: requireAccessibleEntrances
            )
        else {
            return nil
        }

        var best: GraphEntryResult?
        for candidate in dataset.nodes {
            guard shortestPath(from: candidate.id, to: destinationNode.id) != nil else { continue }
            let distanceToCandidate = distance(from: origin, to: candidate.coordinate)
            if best == nil || distanceToCandidate < best!.distanceFromOrigin {
                best = GraphEntryResult(node: candidate, distanceFromOrigin: distanceToCandidate)
            }
        }

        return best
    }

    private func anchors(
        for buildingName: String,
        preferredAnchorNodeID: String?,
        requireAccessibleEntrances: Bool
    ) -> [OutdoorBuildingAnchor] {
        let normalized = normalize(buildingName)
        let buildingAnchors = dataset.anchors.filter { normalize($0.buildingName) == normalized }
        guard !buildingAnchors.isEmpty else { return [] }

        let filteredAnchors: [OutdoorBuildingAnchor]
        if requireAccessibleEntrances {
            filteredAnchors = buildingAnchors.filter(isAnchorAccessible(_:))
        } else {
            filteredAnchors = buildingAnchors
        }

        if let preferredAnchorNodeID,
           let preferred = filteredAnchors.first(where: { $0.anchorNodeID == preferredAnchorNodeID }) {
            return [preferred] + filteredAnchors.filter { $0.anchorNodeID != preferredAnchorNodeID }
        }

        return filteredAnchors
    }

    private func destinationNodeForBootstrap(
        from origin: CLLocationCoordinate2D,
        destinationName: String,
        preferredAnchorNodeID: String?,
        requireAccessibleEntrances: Bool
    ) -> OutdoorGraphNode? {
        let anchorCandidates = anchors(
            for: destinationName,
            preferredAnchorNodeID: preferredAnchorNodeID,
            requireAccessibleEntrances: requireAccessibleEntrances
        )
        guard !anchorCandidates.isEmpty else { return nil }

        var bestNode: OutdoorGraphNode?
        var bestDistance: CLLocationDistance = .infinity

        for anchor in anchorCandidates {
            guard let node = nodesByID[anchor.anchorNodeID] else { continue }
            let candidateDistance = distance(from: origin, to: node.coordinate)
            if candidateDistance < bestDistance {
                bestDistance = candidateDistance
                bestNode = node
            }
        }

        return bestNode
    }

    private func isAnchorAccessible(_ anchor: OutdoorBuildingAnchor) -> Bool {
        if !anchor.isAccessible {
            return false
        }

        let nonAccessibleNodeIDs: Set<String> = [
            "price-stair-entrance",
            "uc-main-entrance",
            "marsh-north-entrance",
            "marsh-south-entrance"
        ]
        return !nonAccessibleNodeIDs.contains(anchor.anchorNodeID)
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

    private func edgeCoordinates(
        for nodeIDs: [String],
        origin: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        let nodePairs = Array(zip(nodeIDs, nodeIDs.dropFirst()))
        var coordinates: [CLLocationCoordinate2D] = []

        if nodePairs.isEmpty, let firstNodeID = nodeIDs.first, let firstNode = nodesByID[firstNodeID] {
            coordinates.append(firstNode.coordinate)
        }

        if let firstPair = nodePairs.first {
            appendCoordinates(
                trimmedLeadingEdgeCoordinates(
                    from: firstPair.0,
                    to: firstPair.1,
                    origin: origin
                ),
                into: &coordinates
            )
        }

        for pair in nodePairs.dropFirst() {
            appendCoordinates(
                shapedCoordinates(from: pair.0, to: pair.1),
                into: &coordinates
            )
        }

        return coordinates
    }

    private func shapedCoordinates(from fromNodeID: String, to toNodeID: String) -> [CLLocationCoordinate2D] {
        if let edge = edge(from: fromNodeID, to: toNodeID) {
            return coordinates(for: edge, travelingFrom: fromNodeID, to: toNodeID)
        }

        guard let fromNode = nodesByID[fromNodeID], let toNode = nodesByID[toNodeID] else {
            return []
        }

        return [fromNode.coordinate, toNode.coordinate]
    }

    private func edge(from fromNodeID: String, to toNodeID: String) -> OutdoorGraphEdge? {
        if let exact = edgesByNodePair["\(fromNodeID)->\(toNodeID)"] {
            return exact
        }

        if let reversed = edgesByNodePair["\(toNodeID)->\(fromNodeID)"], reversed.bidirectional {
            return reversed
        }

        return nil
    }

    private func coordinates(
        for edge: OutdoorGraphEdge,
        travelingFrom fromNodeID: String,
        to toNodeID: String
    ) -> [CLLocationCoordinate2D] {
        let shapeCoordinates = (edge.shape ?? []).map(\.coordinate)

        guard !shapeCoordinates.isEmpty else {
            return fallbackCoordinates(from: fromNodeID, to: toNodeID)
        }

        let isForward = edge.fromNodeID == fromNodeID && edge.toNodeID == toNodeID
        let isReverse = edge.bidirectional && edge.fromNodeID == toNodeID && edge.toNodeID == fromNodeID

        if isForward {
            return normalizeShape(shapeCoordinates, from: fromNodeID, to: toNodeID)
        }

        if isReverse {
            return normalizeShape(shapeCoordinates.reversed(), from: fromNodeID, to: toNodeID)
        }

        return fallbackCoordinates(from: fromNodeID, to: toNodeID)
    }

    private func normalizeShape(
        _ shapeCoordinates: [CLLocationCoordinate2D],
        from fromNodeID: String,
        to toNodeID: String
    ) -> [CLLocationCoordinate2D] {
        guard
            let fromNode = nodesByID[fromNodeID],
            let toNode = nodesByID[toNodeID]
        else {
            return Array(shapeCoordinates)
        }

        var normalized = Array(shapeCoordinates)
        if !sameCoordinate(fromNode.coordinate, normalized.first) {
            normalized.insert(fromNode.coordinate, at: 0)
        }
        if !sameCoordinate(toNode.coordinate, normalized.last) {
            normalized.append(toNode.coordinate)
        }
        return normalized
    }

    private func fallbackCoordinates(from fromNodeID: String, to toNodeID: String) -> [CLLocationCoordinate2D] {
        guard let fromNode = nodesByID[fromNodeID], let toNode = nodesByID[toNodeID] else {
            return []
        }
        return [fromNode.coordinate, toNode.coordinate]
    }

    private func trimmedLeadingEdgeCoordinates(
        from fromNodeID: String,
        to toNodeID: String,
        origin: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        let coordinates = shapedCoordinates(from: fromNodeID, to: toNodeID)
        guard coordinates.count >= 2 else { return coordinates }

        guard let projection = projectedPoint(from: origin, onto: coordinates),
              projection.distanceToPath <= leadingEdgeJoinThreshold else {
            return coordinates
        }

        var trimmed: [CLLocationCoordinate2D] = [projection.coordinate]
        let remainingCoordinates = coordinates.dropFirst(projection.nextCoordinateIndex)
        appendCoordinates(Array(remainingCoordinates), into: &trimmed)
        return trimmed
    }

    private func projectedPoint(
        from origin: CLLocationCoordinate2D,
        onto coordinates: [CLLocationCoordinate2D]
    ) -> ProjectedPathPoint? {
        guard coordinates.count >= 2 else { return nil }

        let originPoint = MKMapPoint(origin)
        var bestProjection: ProjectedPathPoint?

        for (index, pair) in zip(coordinates.indices, zip(coordinates, coordinates.dropFirst())) {
            let startPoint = MKMapPoint(pair.0)
            let endPoint = MKMapPoint(pair.1)
            let dx = endPoint.x - startPoint.x
            let dy = endPoint.y - startPoint.y
            let segmentLengthSquared = dx * dx + dy * dy

            let projectionPoint: MKMapPoint
            if segmentLengthSquared <= .ulpOfOne {
                projectionPoint = startPoint
            } else {
                let t = max(
                    0,
                    min(
                        1,
                        ((originPoint.x - startPoint.x) * dx + (originPoint.y - startPoint.y) * dy)
                            / segmentLengthSquared
                    )
                )
                projectionPoint = MKMapPoint(
                    x: startPoint.x + dx * t,
                    y: startPoint.y + dy * t
                )
            }

            let distanceToPath = originPoint.distance(to: projectionPoint)
            let candidate = ProjectedPathPoint(
                coordinate: projectionPoint.coordinate,
                distanceToPath: distanceToPath,
                nextCoordinateIndex: index + 1
            )

            if bestProjection == nil || distanceToPath < bestProjection!.distanceToPath {
                bestProjection = candidate
            }
        }

        return bestProjection
    }

    private func appendCoordinates(
        _ newCoordinates: [CLLocationCoordinate2D],
        into coordinates: inout [CLLocationCoordinate2D]
    ) {
        for coordinate in newCoordinates where !sameCoordinate(coordinate, coordinates.last) {
            coordinates.append(coordinate)
        }
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

private struct ProjectedPathPoint {
    let coordinate: CLLocationCoordinate2D
    let distanceToPath: CLLocationDistance
    let nextCoordinateIndex: Int
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
