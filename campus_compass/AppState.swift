//
//  AppState.swift
//  campus_compass
//
<<<<<<< HEAD
//  Created by NiLyssa Walker on 2/21/26.
=======
//  Created by NiLyssa Walker on 2/17/26.
>>>>>>> 12cf386 (fixed selected location functionaity to disappear when a route has started)
//

import Foundation
import CoreLocation
import Combine
<<<<<<< HEAD
import CloudKit

final class AppState: ObservableObject {
    @Published var selectedTab: Int = 0          // 0 Home, 1 Map, 2 Settings (matches your tags)
    @Published var selectedBuildingID: CKRecord.ID? = nil
=======

final class AppState: ObservableObject {
    @Published var selectedTab: Int = 0          // 0 Home, 1 Map, 2 Settings (matches your tags)
    @Published var selectedBuildingID: UUID? = nil
>>>>>>> 12cf386 (fixed selected location functionaity to disappear when a route has started)
}
