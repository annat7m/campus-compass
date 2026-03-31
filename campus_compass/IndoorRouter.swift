//
//  IndoorRouter.swift
//  campus_compass
//
//  Created by Anna on 3/30/26.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Graph Models

struct IndoorRoutingNode {
    let id: String
    let floorId: String
    let coordinate: CLLocationCoordinate2D
    let geometryIds: [String]
}

enum IndoorEdgeType {
    case walk, stairs, elevator
}

struct IndoorRoutingEdge {
    let toNodeId: String
    let cost: Double
    let type: IndoorEdgeType
}

struct IndoorRoutingGraph {
    var nodes: [String: IndoorRoutingNode] = [:]
    var adjacency: [String: [IndoorRoutingEdge]] = [:]
    var geometryToNodes: [String: [String]] = [:]

    func nearestNode(to coordinate: CLLocationCoordinate2D, onFloor floorId: String) -> IndoorRoutingNode? {
        nearestNode(to: coordinate, onFloor: floorId, connectedOnly: false)
    }

    func nearestConnectedNode(to coordinate: CLLocationCoordinate2D, onFloor floorId: String) -> IndoorRoutingNode? {
        nearestNode(to: coordinate, onFloor: floorId, connectedOnly: true)
            ?? nearestNode(to: coordinate, onFloor: floorId, connectedOnly: false)
    }

    func nearestConnectedNode(to coordinate: CLLocationCoordinate2D, searchingAllFloors: Bool) -> IndoorRoutingNode? {
        guard searchingAllFloors else { return nil }
        let ref = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return nodes.values
            .filter { !(adjacency[$0.id]?.isEmpty ?? true) }
            .min {
                ref.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) <
                ref.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
            }
    }

    private func nearestNode(to coordinate: CLLocationCoordinate2D,
                             onFloor floorId: String,
                             connectedOnly: Bool) -> IndoorRoutingNode? {
        let ref = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return nodes.values
            .filter { $0.floorId == floorId && (!connectedOnly || !(adjacency[$0.id]?.isEmpty ?? true)) }
            .min {
                ref.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) <
                ref.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
            }
    }
}

// MARK: - Route Models

struct IndoorRouteStep: Identifiable {
    let id = UUID()
    let instruction: String
    let distance: Double
    let floorId: String
    let isTransition: Bool
}

struct IndoorRoute {
    let steps: [IndoorRouteStep]
    let coordinatesByFloor: [String: [CLLocationCoordinate2D]]
    let totalDistance: Double
    let destinationName: String
}

// MARK: - JSON Decoding DTOs

private struct NodeFeatureCollection: Decodable {
    let features: [NodeFeature]
}

private struct NodeFeature: Decodable {
    let geometry: NodeGeometry
    let properties: NodeProperties
}

private struct NodeGeometry: Decodable {
    let coordinates: [Double]
}

private struct NodeProperties: Decodable {
    let id: String
    let geometryIds: [String]
    let neighbors: [NeighborDTO]
}

private struct NeighborDTO: Decodable {
    let id: String
    let extraCost: Double
    let flags: [Int]
}

private struct ConnectionDTO: Decodable {
    let id: String
    let type: String
    let entrances: [ConnectionEndpoint]
    let exits: [ConnectionEndpoint]
    let entryCost: Double
    let floorCostMultiplier: Double
}

private struct ConnectionEndpoint: Decodable {
    let geometryId: String
    let floorId: String
    let flags: [Int]
}

// MARK: - Graph Loader

enum IndoorRoutingLoader {
    static func load(from baseURL: URL) -> IndoorRoutingGraph {
        var graph = IndoorRoutingGraph()
        loadNodes(from: baseURL, into: &graph)
        loadConnections(from: baseURL, into: &graph)
        return graph
    }

    private static func loadNodes(from baseURL: URL, into graph: inout IndoorRoutingGraph) {
        let nodesBase = baseURL.appendingPathComponent("nodes")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: nodesBase, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }

        let decoder = JSONDecoder()
        for fileURL in files where fileURL.pathExtension.lowercased() == "geojson" {
            let floorId = fileURL.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: fileURL),
                  let collection = try? decoder.decode(NodeFeatureCollection.self, from: data) else { continue }

            for feature in collection.features {
                guard feature.geometry.coordinates.count >= 2 else { continue }
                let nodeId = feature.properties.id
                let node = IndoorRoutingNode(
                    id: nodeId,
                    floorId: floorId,
                    coordinate: CLLocationCoordinate2D(
                        latitude: feature.geometry.coordinates[1],
                        longitude: feature.geometry.coordinates[0]
                    ),
                    geometryIds: feature.properties.geometryIds
                )
                graph.nodes[nodeId] = node
                for geoId in feature.properties.geometryIds {
                    graph.geometryToNodes[geoId, default: []].append(nodeId)
                }

                let edges = feature.properties.neighbors.map { neighbor in
                    IndoorRoutingEdge(
                        toNodeId: neighbor.id,
                        cost: neighbor.extraCost,
                        type: neighbor.flags.contains(4) ? .stairs : .walk
                    )
                }
                graph.adjacency[nodeId, default: []].append(contentsOf: edges)
            }
        }
    }

    private static func loadConnections(from baseURL: URL, into graph: inout IndoorRoutingGraph) {
        let url = baseURL.appendingPathComponent("connections.json")
        guard let data = try? Data(contentsOf: url),
              let connections = try? JSONDecoder().decode([ConnectionDTO].self, from: data) else { return }

        for connection in connections {
            let edgeType: IndoorEdgeType = connection.type == "elevator" ? .elevator : .stairs

            // Gather entrance nodes and exit nodes separately per floor
            var entrancesByFloor: [String: [IndoorRoutingNode]] = [:]
            var exitsByFloor: [String: [IndoorRoutingNode]] = [:]

            for endpoint in connection.entrances {
                let geoNodes = nodesForGeometry(endpoint.geometryId, onFloor: endpoint.floorId, in: graph)
                entrancesByFloor[endpoint.floorId, default: []].append(contentsOf: geoNodes)
            }
            for endpoint in connection.exits {
                let geoNodes = nodesForGeometry(endpoint.geometryId, onFloor: endpoint.floorId, in: graph)
                exitsByFloor[endpoint.floorId, default: []].append(contentsOf: geoNodes)
            }

            // Combine all floors involved
            var allByFloor: [String: [IndoorRoutingNode]] = [:]
            for (floor, nodes) in entrancesByFloor { allByFloor[floor, default: []].append(contentsOf: nodes) }
            for (floor, nodes) in exitsByFloor     { allByFloor[floor, default: []].append(contentsOf: nodes) }

            let floors = Array(allByFloor.keys)

            // Cross-floor edges (stairs / elevator)
            for i in 0..<floors.count {
                for j in (i + 1)..<floors.count {
                    let nodesA = allByFloor[floors[i]] ?? []
                    let nodesB = allByFloor[floors[j]] ?? []
                    for nodeA in nodesA {
                        for nodeB in nodesB {
                            graph.adjacency[nodeA.id, default: []].append(
                                IndoorRoutingEdge(toNodeId: nodeB.id, cost: connection.entryCost, type: edgeType))
                            graph.adjacency[nodeB.id, default: []].append(
                                IndoorRoutingEdge(toNodeId: nodeA.id, cost: connection.entryCost, type: edgeType))
                        }
                    }
                }
            }

            // Same-floor door edges — connect entrances to exits on the same floor
            // (these were previously ignored by the cross-floor-only loop)
            if connection.type == "door" {
                for floor in floors {
                    let entrances = entrancesByFloor[floor] ?? []
                    let exits     = exitsByFloor[floor] ?? []
                    for nodeA in entrances {
                        for nodeB in exits where nodeA.id != nodeB.id {
                            graph.adjacency[nodeA.id, default: []].append(
                                IndoorRoutingEdge(toNodeId: nodeB.id, cost: connection.entryCost, type: .walk))
                            graph.adjacency[nodeB.id, default: []].append(
                                IndoorRoutingEdge(toNodeId: nodeA.id, cost: connection.entryCost, type: .walk))
                        }
                    }
                }
            }
        }
    }

    private static func nodesForGeometry(_ geometryId: String, onFloor floorId: String, in graph: IndoorRoutingGraph) -> [IndoorRoutingNode] {
        (graph.geometryToNodes[geometryId] ?? []).compactMap { nodeId -> IndoorRoutingNode? in
            guard let node = graph.nodes[nodeId], node.floorId == floorId else { return nil }
            return node
        }
    }
}

// MARK: - Router (Dijkstra)

enum IndoorRouter {
    static func route(
        from startCoord: CLLocationCoordinate2D,
        startFloorId: String,
        to destination: IndoorLocation,
        destinationFloorId: String,
        graph: IndoorRoutingGraph,
        floorNames: [String: String],
        accessibility: AccessibilityProfile = .init()
    ) -> IndoorRoute? {
        let allNodes = graph.nodes.count
        let allEdges = graph.adjacency.values.reduce(0) { $0 + $1.count }
        let startFloorNodes = graph.nodes.values.filter { $0.floorId == startFloorId }.count
        let destFloorNodes  = graph.nodes.values.filter { $0.floorId == destinationFloorId }.count
        let crossFloorEdges = graph.adjacency.values.flatMap { $0 }.filter { $0.type != .walk }.count
        print("[IndoorRouter] graph: \(allNodes) nodes, \(allEdges) edges (\(crossFloorEdges) cross-floor)")
        print("[IndoorRouter] start floor '\(startFloorId)': \(startFloorNodes) nodes")
        print("[IndoorRouter] dest  floor '\(destinationFloorId)': \(destFloorNodes) nodes")

        // Use nearest connected node so Dijkstra has somewhere to go from both ends.
        // If the dest floor has no connected nodes at all, expand search across all floors
        // of the building (cross-floor edges will carry us there).
        let startNode = graph.nearestConnectedNode(to: startCoord, onFloor: startFloorId)
        var endNode   = graph.nearestConnectedNode(to: destination.coordinate, onFloor: destinationFloorId)
        if endNode == nil {
            // Dest floor has no connected nodes — find closest connected node across all floors
            endNode = graph.nearestConnectedNode(to: destination.coordinate, searchingAllFloors: true)
            print("[IndoorRouter] dest floor has no connected nodes; expanded search — endNode on \(endNode?.floorId ?? "none")")
        }

        guard let startNode, let endNode else {
            print("[IndoorRouter] ERROR: could not find start or end node on their floors")
            return nil
        }
        print("[IndoorRouter] startNode=\(startNode.id) on \(startNode.floorId), endNode=\(endNode.id) on \(endNode.floorId)")
        let startEdges = graph.adjacency[startNode.id]?.count ?? 0
        let endEdges   = graph.adjacency[endNode.id]?.count ?? 0
        print("[IndoorRouter] startNode has \(startEdges) edges, endNode has \(endEdges) edges")

        if startNode.id == endNode.id || startCoord.latitude == destination.coordinate.latitude {
            return IndoorRoute(
                steps: [IndoorRouteStep(
                    instruction: "You are near \(destination.name)",
                    distance: 0,
                    floorId: startFloorId,
                    isTransition: false)],
                coordinatesByFloor: [:],
                totalDistance: 0,
                destinationName: destination.name
            )
        }

        // Dijkstra with a sorted array as priority queue
        var dist: [String: Double] = [startNode.id: 0]
        var prev: [String: (prevId: String, edge: IndoorRoutingEdge)] = [:]
        var heap: [(cost: Double, nodeId: String)] = [(0, startNode.id)]

        while !heap.isEmpty {
            let (currentCost, currentId) = heap.removeFirst()
            if currentId == endNode.id { break }
            guard currentCost <= (dist[currentId] ?? .greatestFiniteMagnitude) else { continue }

            for edge in graph.adjacency[currentId] ?? [] {
                if accessibility.elevatorsOnly && edge.type == .stairs { continue }
                let newCost = currentCost + effectiveCost(edge: edge, accessibility: accessibility)
                if newCost < (dist[edge.toNodeId] ?? .greatestFiniteMagnitude) {
                    dist[edge.toNodeId] = newCost
                    prev[edge.toNodeId] = (prevId: currentId, edge: edge)
                    let idx = heap.firstIndex(where: { $0.cost > newCost }) ?? heap.endIndex
                    heap.insert((newCost, edge.toNodeId), at: idx)
                }
            }
        }

        print("[IndoorRouter] Dijkstra visited \(dist.count) nodes. Reached end: \(dist[endNode.id] != nil), cost: \(dist[endNode.id] ?? -1)")

        // If exact end node unreachable (disconnected component), fall back to the closest
        // reachable node on the destination floor and add a walk instruction for the last stretch.
        let resolvedEndNode: IndoorRoutingNode
        var needsWalkSuffix = false
        if dist[endNode.id] == nil {
            let destLoc = CLLocation(latitude: destination.coordinate.latitude,
                                     longitude: destination.coordinate.longitude)
            let fallback = dist.keys
                .compactMap { graph.nodes[$0] }
                .filter { $0.floorId == destinationFloorId }
                .min {
                    destLoc.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) <
                    destLoc.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
                }
            // If no reachable node on dest floor at all, try any reachable node
            ?? dist.keys
                .compactMap { graph.nodes[$0] }
                .min {
                    destLoc.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) <
                    destLoc.distance(from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude))
                }
            guard let fallback else { return nil }
            print("[IndoorRouter] using fallback endNode \(fallback.id) on \(fallback.floorId)")
            resolvedEndNode = fallback
            needsWalkSuffix = true
        } else {
            resolvedEndNode = endNode
        }

        // Reconstruct path
        var nodeIds: [String] = []
        var edgeForNode: [String: IndoorRoutingEdge] = [:]
        var current = resolvedEndNode.id
        while current != startNode.id {
            nodeIds.insert(current, at: 0)
            guard let entry = prev[current] else { break }
            edgeForNode[current] = entry.edge
            current = entry.prevId
        }
        nodeIds.insert(startNode.id, at: 0)

        let pathNodes = nodeIds.compactMap { graph.nodes[$0] }

        // Build coordinatesByFloor
        var coordinatesByFloor: [String: [CLLocationCoordinate2D]] = [:]
        for node in pathNodes {
            coordinatesByFloor[node.floorId, default: []].append(node.coordinate)
        }

        let steps = buildSteps(
            pathNodes: pathNodes,
            edgeForNode: edgeForNode,
            destination: destination,
            floorNames: floorNames,
            needsWalkSuffix: needsWalkSuffix
        )
        return IndoorRoute(
            steps: steps,
            coordinatesByFloor: coordinatesByFloor,
            totalDistance: dist[resolvedEndNode.id] ?? 0,
            destinationName: destination.name
        )
    }

    private static func effectiveCost(edge: IndoorRoutingEdge, accessibility: AccessibilityProfile) -> Double {
        switch edge.type {
        case .walk:     return edge.cost
        case .stairs:   return edge.cost * accessibility.stairsPenalty
        case .elevator: return edge.cost + 5
        }
    }

    private static func buildSteps(
        pathNodes: [IndoorRoutingNode],
        edgeForNode: [String: IndoorRoutingEdge],
        destination: IndoorLocation,
        floorNames: [String: String],
        needsWalkSuffix: Bool
    ) -> [IndoorRouteStep] {
        var steps: [IndoorRouteStep] = []
        var i = 1
        while i < pathNodes.count {
            let from = pathNodes[i - 1]
            let to = pathNodes[i]
            if from.floorId != to.floorId {
                let edge = edgeForNode[to.id]
                let toFloorName = floorNames[to.floorId] ?? "next floor"
                let verb = edge?.type == .elevator ? "Take elevator to" : "Take stairs to"
                steps.append(IndoorRouteStep(
                    instruction: "\(verb) \(toFloorName)",
                    distance: edge?.cost ?? 0,
                    floorId: from.floorId,
                    isTransition: true
                ))
            }
            i += 1
        }
        if let lastNode = pathNodes.last {
            if needsWalkSuffix {
                let ref = CLLocation(latitude: lastNode.coordinate.latitude, longitude: lastNode.coordinate.longitude)
                let destLoc = CLLocation(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude)
                let remaining = ref.distance(from: destLoc)
                let dist = remaining < 1 ? "" : " (~\(Int(remaining))m)"
                steps.append(IndoorRouteStep(
                    instruction: "Continue to \(destination.name)\(dist)",
                    distance: remaining,
                    floorId: lastNode.floorId,
                    isTransition: false
                ))
            } else {
                steps.append(IndoorRouteStep(
                    instruction: "Arrive at \(destination.name)",
                    distance: 0,
                    floorId: lastNode.floorId,
                    isTransition: false
                ))
            }
        }
        if steps.isEmpty {
            let floorId = pathNodes.first?.floorId ?? ""
            steps.append(IndoorRouteStep(
                instruction: "Head to \(destination.name)",
                distance: 0,
                floorId: floorId,
                isTransition: false
            ))
        }
        return steps
    }
}
