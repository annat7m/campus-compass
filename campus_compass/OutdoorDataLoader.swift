//
//  OutdoorDataLoader.swift
//  Campus Compass
//
//  Created by Codex on 3/28/26.
//

import Foundation

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

        return OutdoorGraphDataset(nodes: nodes, edges: edges, anchors: anchors)
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL, using decoder: JSONDecoder) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
