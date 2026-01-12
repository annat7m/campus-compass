//
//  NavigationModels.swift
//  campus_compass
//
//  Created by Anna on 11/25/25.
//

import Foundation
import CoreLocation

//  struct:      AccessibilityProfile
//
//  Description: model that is responsible for user’s
//               accessibility settings that influence routing
struct AccessibilityProfile: Codable, Equatable {
    // if false, stairs are avoided when possible
    var stairsAllowed: Bool

    // if true, only elevators and ramps should be used
    var elevatorsOnly: Bool

    // extra cost multiplier for stairs (e.g. 5.0 means “stair distance counts 5×”).
    var stairsPenalty: Double

    init(stairsAllowed: Bool = true,
         elevatorsOnly: Bool = false,
         stairsPenalty: Double = 5.0) {
        self.stairsAllowed = stairsAllowed
        self.elevatorsOnly = elevatorsOnly
        self.stairsPenalty = stairsPenalty
    }
}

//  struct:      Campus
//
//  Description: Logical campus container
struct Campus {
    var id: UUID
    var name: String
    var buildings: [Building]

    init(id: UUID = UUID(), name: String, buildings: [Building]) {
        self.id = id
        self.name = name
        self.buildings = buildings
    }
}

//  struct:      POI
//
//  Description: Point-of-interest inside a building/floor
//               (water fountains, elevators, bathrooms, AEDs, etc.)
//  Notes:       need to encode/decode latitude & longitude manually :((((
struct POI: Identifiable, Codable, Hashable {
    var id: UUID
    var type: String
    var latitude: Double
    var longitude: Double
    var floorId: UUID

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

//  struct:      GraphNode
//
//  Description: Node in the routing graph.
//               Roughly: hallway junction, door, stair landing, etc
struct GraphNode: Identifiable, Hashable {
    let id: UUID
    let x: Double
    let y: Double
    let floorId: UUID
}

//  struct:      GraphEdge
//
//  Description: Edge between two graph nodes (a walkable segment)
struct GraphEdge: Hashable {
    let from: UUID       // GraphNode.id
    let to: UUID         // GraphNode.id
    let baseCost: Double // geometric distance (m, ft, arbitrary units, etc)
    
    let attrs: [String: String] // stairs, elevator, ramp, etc
}

//  struct:      MapGraph
//
//  Description: entire graph of nodes and endges
struct MapGraph {
    var nodes: [UUID: GraphNode]
    var edges: [GraphEdge]

    init(nodes: [UUID: GraphNode] = [:], edges: [GraphEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
}

// struct:      RouteSegment
//
// Description: one segment of a route - one direction
//              exmaple: "Turn right", "Take elevator to Floor 2", ...
struct RouteSegment {
    let start: GraphNode
    let end: GraphNode
    let instruction: String
    let distance: Double
}

// struct:      RouteSegment
//
// Description: full route that consists of routing segments
//
struct Route {
    let segments: [RouteSegment]
    let distance: Double
    let eta: TimeInterval
}
