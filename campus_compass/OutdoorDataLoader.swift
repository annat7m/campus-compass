//
//  OutdoorDataLoader.swift
//  Campus Compass
//
//  Created by Codex on 3/28/26.
//

import Foundation
import CoreLocation

enum OutdoorDataLoader {
    static func loadCampusOutdoorData() -> OutdoorGraphDataset {
        let folderName = "CampusOutdoorData"
        guard let baseURL = Bundle.main.resourceURL?.appendingPathComponent(folderName) else {
            return .empty
        }

        let decoder = JSONDecoder()

        let nodes: [OutdoorGraphNode] = load(
            [OutdoorGraphNode].self,
            from: baseURL.appendingPathComponent("nodes.json"),
            using: decoder
        ) ?? []

        let edges: [OutdoorGraphEdge] = load(
            [OutdoorGraphEdge].self,
            from: baseURL.appendingPathComponent("edges.json"),
            using: decoder
        ) ?? []

        let anchors: [OutdoorBuildingAnchor] = load(
            [OutdoorBuildingAnchor].self,
            from: baseURL.appendingPathComponent("anchors.json"),
            using: decoder
        ) ?? []

        return normalizedDataset(nodes: nodes, edges: edges, anchors: anchors)
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL, using decoder: JSONDecoder) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func normalizedDataset(
        nodes: [OutdoorGraphNode],
        edges: [OutdoorGraphEdge],
        anchors: [OutdoorBuildingAnchor]
    ) -> OutdoorGraphDataset {
        var mergedEdges = edges
        var mergedAnchors = anchors

        let nodeIDs = Set(nodes.map(\.id))
        let existingEdgeIDs = Set(edges.map(\.id))
        var existingEdgeEndpoints = Set(edges.map { edgeKey(from: $0.fromNodeID, to: $0.toNodeID) })

        func ensureEdge(
            id: String,
            fromNodeID: String,
            toNodeID: String,
            distance: CLLocationDistance,
            pathType: String
        ) {
            guard nodeIDs.contains(fromNodeID), nodeIDs.contains(toNodeID) else { return }
            guard !existingEdgeIDs.contains(id) else { return }

            let key = edgeKey(from: fromNodeID, to: toNodeID)
            guard !existingEdgeEndpoints.contains(key) else { return }

            mergedEdges.append(
                OutdoorGraphEdge(
                    id: id,
                    fromNodeID: fromNodeID,
                    toNodeID: toNodeID,
                    distance: distance,
                    penalty: 0,
                    bidirectional: true,
                    pathType: pathType,
                    shape: nil
                )
            )
            existingEdgeEndpoints.insert(key)
        }

        // Ensure newly added alternate entrances are connected into the walk graph.
        ensureEdge(
            id: "edge-uc-side-uc-tran",
            fromNodeID: "uc-side-entrance",
            toNodeID: "tromble-uc-tran-walk",
            distance: 12,
            pathType: "entrance"
        )
        ensureEdge(
            id: "edge-price-stair-east-corner",
            fromNodeID: "price-stair-entrance",
            toNodeID: "tromble-east-corner-walk",
            distance: 40,
            pathType: "entrance"
        )

        let existingAnchorNodeIDs = Set(anchors.map(\.anchorNodeID))
        if nodeIDs.contains("uc-side-entrance"), !existingAnchorNodeIDs.contains("uc-side-entrance") {
            mergedAnchors.append(
                OutdoorBuildingAnchor(
                    id: "anchor-university-center-side",
                    buildingName: "University Center",
                    anchorNodeID: "uc-side-entrance",
                    isAccessible: true
                )
            )
        }
        if nodeIDs.contains("price-stair-entrance"), !existingAnchorNodeIDs.contains("price-stair-entrance") {
            mergedAnchors.append(
                OutdoorBuildingAnchor(
                    id: "anchor-price-stair",
                    buildingName: "Price Hall",
                    anchorNodeID: "price-stair-entrance",
                    isAccessible: false
                )
            )
        }
        if nodeIDs.contains("marsh-north-entrance"), !existingAnchorNodeIDs.contains("marsh-north-entrance") {
            mergedAnchors.append(
                OutdoorBuildingAnchor(
                    id: "anchor-marsh-north",
                    buildingName: "Marsh Hall",
                    anchorNodeID: "marsh-north-entrance",
                    isAccessible: false
                )
            )
        }
        if nodeIDs.contains("marsh-south-entrance"), !existingAnchorNodeIDs.contains("marsh-south-entrance") {
            mergedAnchors.append(
                OutdoorBuildingAnchor(
                    id: "anchor-marsh-south",
                    buildingName: "Marsh Hall",
                    anchorNodeID: "marsh-south-entrance",
                    isAccessible: false
                )
            )
        }

        // Respect known non-accessible entrances regardless of source data.
        mergedAnchors = mergedAnchors.map { anchor in
            let nonAccessibleNodeIDs: Set<String> = [
                "uc-main-entrance",
                "price-stair-entrance",
                "marsh-north-entrance",
                "marsh-south-entrance"
            ]
            if nonAccessibleNodeIDs.contains(anchor.anchorNodeID) {
                return OutdoorBuildingAnchor(
                    id: anchor.id,
                    buildingName: anchor.buildingName,
                    anchorNodeID: anchor.anchorNodeID,
                    isAccessible: false
                )
            }
            return anchor
        }

        return OutdoorGraphDataset(nodes: nodes, edges: mergedEdges, anchors: mergedAnchors)
    }

    private static func edgeKey(from: String, to: String) -> String {
        from < to ? "\(from)|\(to)" : "\(to)|\(from)"
    }
}
