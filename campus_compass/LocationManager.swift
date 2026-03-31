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
    private var smoothedLocation: CLLocation? = nil

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 3
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

        // Ignore invalid, stale, or very inaccurate readings.
        guard latest.horizontalAccuracy > 0, latest.horizontalAccuracy <= 20 else { return }
        guard abs(latest.timestamp.timeIntervalSinceNow) <= 10 else { return }

        guard let current = smoothedLocation else {
            smoothedLocation = latest
            location = latest
            return
        }

        let distance = latest.distance(from: current)
        let improvedAccuracy = latest.horizontalAccuracy + 3 < current.horizontalAccuracy
        let minimumMovement = max(3, min(latest.horizontalAccuracy, 10))

        if distance < minimumMovement && !improvedAccuracy {
            return
        }

        if distance > 35 {
            smoothedLocation = latest
            location = latest
            return
        }

        let blendFactor = distance < 12 ? 0.25 : 0.5
        let blendedCoordinate = CLLocationCoordinate2D(
            latitude: current.coordinate.latitude + ((latest.coordinate.latitude - current.coordinate.latitude) * blendFactor),
            longitude: current.coordinate.longitude + ((latest.coordinate.longitude - current.coordinate.longitude) * blendFactor)
        )
        let filteredLocation = CLLocation(
            coordinate: blendedCoordinate,
            altitude: latest.altitude,
            horizontalAccuracy: min(latest.horizontalAccuracy, current.horizontalAccuracy),
            verticalAccuracy: latest.verticalAccuracy,
            course: latest.course,
            speed: latest.speed,
            timestamp: latest.timestamp
        )

        smoothedLocation = filteredLocation
        location = filteredLocation
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}
