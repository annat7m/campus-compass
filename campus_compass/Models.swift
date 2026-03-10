//
//  Models.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 11/3/25.
//

import Foundation
import SwiftData
import CoreLocation
import CloudKit

struct CampusBuilding: Identifiable {
    let id: CKRecord.ID              // CloudKit record identifier
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init?(record: CKRecord) {
        guard
            let name = record["Name"] as? String,
            let lat = record["Latitude"] as? Double,
            let lon = record["Longitude"] as? Double
        else { return nil }

        self.id = record.recordID
        self.name = name
        self.latitude = lat
        self.longitude = lon
    }
}

//User information

@Model
class UserProfile {
    var name: String = ""

    // Accessibility
    var accessibilityMode: Bool = false
    var avoidStairs: Bool = false
    var voiceNavigation: Bool = true
    var largeText: Bool = false

    // Notifications
    var navigationUpdates: Bool = true

    // Preferences
    var scenicRoute: Bool = false
    var quietPath: Bool = false

    // Existing lists
    var recentLocations: [String] = []
    var favorites: [String] = []

    init(
        name: String,
        accessibilityMode: Bool = false,
        avoidStairs: Bool = false,
        voiceNavigation: Bool = true,
        largeText: Bool = false,
        navigationUpdates: Bool = true,
        scenicRoute: Bool = false,
        quietPath: Bool = false,
        recentLocations: [String] = [],
        favorites: [String] = []
    ) {
        self.name = name
        self.accessibilityMode = accessibilityMode
        self.avoidStairs = avoidStairs
        self.voiceNavigation = voiceNavigation
        self.largeText = largeText
        self.navigationUpdates = navigationUpdates
        self.scenicRoute = scenicRoute
        self.quietPath = quietPath
        self.recentLocations = recentLocations
        self.favorites = favorites
    }
}



@Model
class Floor {
    var id: UUID
    var level: Int
    var rooms: [Room]
    var pois: [POIEntity]

    init(id: UUID = UUID(),
         level: Int,
         rooms: [Room] = [],
         pois: [POIEntity] = []) {
        self.id = id
        self.level = level
        self.rooms = rooms
        self.pois = pois
    }
}

@Model
class Room {
    var id: UUID
    var name: String
    var number: String
    // approximate door coordinate so we can hook it to GraphNodes
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(),
         name: String,
         number: String,
         latitude: Double,
         longitude: Double) {
        self.id = id
        self.name = name
        self.number = number
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@Model
class POIEntity {
    var id: UUID
    var type: String
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(),
         type: String,
         latitude: Double,
         longitude: Double) {
        self.id = id
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

