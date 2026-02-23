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
        print("CloudKit container:", CKContainer.default().containerIdentifier ?? "nil")
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Fetch all Buildings (no filter)
        let query = CKQuery(recordType: "Buildings", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "Name", ascending: true)] // optional


        do {
            let (matchResults, _) = try await db.records(matching: query)

            print("Raw matchResults count:", matchResults.count)

            var converted: [CampusBuilding] = []

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    print("Record fields:", record.allKeys())
                    if let b = CampusBuilding(record: record) {
                        converted.append(b)
                    } else {
                        print("⚠️ Could not convert record:", record.recordID.recordName)
                        print("Name:", record["Name"] as Any)
                        print("Latitude:", record["Latitude"] as Any)
                        print("Longitude:", record["Longitude"] as Any)
                    }

                case .failure(let err):
                    print("Record fetch failure:", err)
                }
            }

            print("Converted buildings:", converted.count)
            self.buildings = converted

        } catch {
            print("Query error:", error)
            self.errorMessage = error.localizedDescription
        }
    }
}
