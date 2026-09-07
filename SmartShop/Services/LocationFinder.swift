//
//  LocationFinder.swift
//  SmartShop
//

import CoreLocation

/// One-shot "where am I" with a timeout, the `navigator.geolocation` call in
/// `mitid_.pinkode.tsx`. Asks for when-in-use permission if needed.
final class LocationFinder: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<GeoPoint, Error>?

    struct Denied: Error {}

    func current() async throws -> GeoPoint {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return try await withThrowingTaskGroup(of: GeoPoint.self) { group in
            group.addTask { [self] in
                try await withCheckedThrowingContinuation { cont in
                    continuation = cont
                    switch manager.authorizationStatus {
                    case .notDetermined: manager.requestWhenInUseAuthorization()
                    case .denied, .restricted: cont.resume(throwing: Denied()); continuation = nil
                    default: manager.requestLocation()
                    }
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw Denied()
            }
            let point = try await group.next()!
            group.cancelAll()
            return point
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: continuation?.resume(throwing: Denied()); continuation = nil
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        continuation?.resume(returning: GeoPoint(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude))
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
