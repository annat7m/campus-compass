//
//  AppState.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 2/21/26.
//

import Foundation
import CoreLocation
import Combine

final class AppState: ObservableObject {
    @Published var selectedTab: Int = 0          // 0 Home, 1 Map, 2 Settings (matches your tags)
    @Published var selectedBuildingID: UUID? = nil
}
