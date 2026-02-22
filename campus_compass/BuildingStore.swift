//
//  BuildingStore.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 2/21/26.
//

import Foundation
import CloudKit
import Combine

@MainActor
final class BuildingStore: ObservableObject {
    @Published var buildings: [CampusBuilding] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = CKContainer.default().publicCloudDatabase

    func fetchBuildings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Fetch all Buildings (no filter)
        let query = CKQuery(recordType: "Buildings", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "Name", ascending: true)] // optional

        do {
            var fetched: [CampusBuilding] = []
            var cursor: CKQueryOperation.Cursor? = nil

            repeat {
                // iOS 17+ async CloudKit query
                let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

                if let cursor {
                    result = try await db.records(continuingMatchFrom: cursor, desiredKeys: nil, resultsLimit: 200)
                } else {
                    result = try await db.records(matching: query, desiredKeys: nil, resultsLimit: 200)
                }

                for (_, recordResult) in result.matchResults {
                    if case .success(let record) = recordResult,
                       let building = CampusBuilding(record: record) {
                        fetched.append(building)
                    }
                }

                cursor = result.queryCursor
            } while cursor != nil

            self.buildings = fetched

        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
