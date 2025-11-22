//
//  Models.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 11/3/25.
//

import Foundation
import SwiftData

@Model
class Building {
    var name: String
    var latitude: Double
    var longitude: Double
    var floors: [Floor]

    init(name: String, latitude: Double, longitude: Double, floors: [Floor] = []) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.floors = floors
    }
}

@Model
class Floor {
    var level: Int
    var rooms: [Room]

    init(level: Int, rooms: [Room] = []) {
        self.level = level
        self.rooms = rooms
    }
}

@Model
class Room {
    var name: String
    var number: String

    init(name: String, number: String) {
        self.name = name
        self.number = number
    }
}

//User information

@Model
class UserProfile {
    var name: String
    var userName: String
    var password: String
    var prefersAccessibility: Bool
    var recentLocations: [String]
    var favorites: [String]
    
    init(
        name: String,
        userName: String,
        password: String,
        prefersAccessibility: Bool = false,
        recentLocations: [String] = [],
        favorites: [String] = []
    ) {
        self.name = name
        self.prefersAccessibility = prefersAccessibility
        self.recentLocations = recentLocations
        self.favorites = favorites
        self.userName = userName
        self.password = password
    }
}
