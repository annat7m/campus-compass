//
//  Models.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 11/3/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
class Building {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var floors: [Floor]

    init(id: UUID = UUID(),
             name: String,
             latitude: Double,
             longitude: Double,
             floors: [Floor] = []) {
            self.id = id
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.floors = floors
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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

//User information

@Model
class UserProfile {
    var name: String
    var prefersAccessibility: Bool
    var recentLocations: [String]
    var favorites: [String]
    
    init(
        name: String,
        prefersAccessibility: Bool = false,
        recentLocations: [String] = [],
        favorites: [String] = []
    ) {
        self.name = name
        self.prefersAccessibility = prefersAccessibility
        self.recentLocations = recentLocations
        self.favorites = favorites
    }
}
