//
//  LocationManager.swift
//  campus_compass
//
//  Created by Anna on 11/13/25.
//

//import Foundation
//import CoreLocation
//import Combine
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    @Published var location: CLLocation?
//    private let manager = CLLocationManager()
//
//    override init() {
//        super.init()
//        manager.delegate = self
//        manager.desiredAccuracy = kCLLocationAccuracyBest
//        manager.requestWhenInUseAuthorization()
//        manager.startUpdatingLocation()
//    }
//
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        location = locations.last
//    }
//}

import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermissionAndStart() {
        // Ask only when needed; result comes via delegate callback
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    // iOS 14+
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            // No updates will come; this is where Code=1 happens
            break
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        // Ignore invalid or very inaccurate readings
        guard latest.horizontalAccuracy > 0, latest.horizontalAccuracy <= 25 else { return }

        location = latest
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}

