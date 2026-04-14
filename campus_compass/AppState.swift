//
//  AppState.swift
//  campus_compass
//
//  Created by NiLyssa Walker on 2/21/26.
//

import Foundation
import CoreLocation
import Combine
import CloudKit

final class AppState: ObservableObject {
    @Published var selectedTab: Int = 0          // 0 Home, 1 Map, 2 Settings (matches your tags)
    
    @Published var selectedBuildingID: CKRecord.ID? = nil
    @Published var parkingHighlightRequestID: Int = 0

    func requestParkingHighlights() {
        parkingHighlightRequestID += 1
    }
}
