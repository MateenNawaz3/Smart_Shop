//
//  LocationFinder.swift
//  SmartShop
//

import CoreLocation

/// One-shot "where am I" with a timeout, the `navigator.geolocation` call in
/// `mitid_.pinkode.tsx`. Asks for when-in-use permission if needed.
///
/// Main-actor isolated: `CLLocationManager` is created here and therefore
/// delivers its delegate callbacks here, so the continuation never crosses an
/// isolation boundary and needs no lock of its own.
///
/// `CLLocationManagerDelegate` predates concurrency and is not annotated, so
/// the conformance is marked `@preconcurrency` — the guarantee that callbacks
/// arrive on the main actor comes from CoreLocation delivering them to the
/// run loop the manager was created on, which is this one.
@MainActor
final class LocationFinder: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<GeoPoint, Error>?

    struct Denied: Error {}

    func current() async throws -> GeoPoint {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // A plain timer rather than a racing task group: four callers can all
        // settle this one continuation — permission, a fix, a failure or the
        // timeout — and `finish` is what makes "first one wins" explicit.
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.finish(.failure(Denied()))
        }
        defer { timeout.cancel() }

        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .denied, .restricted: finish(.failure(Denied()))
            default: manager.requestLocation()
            }
        }
    }

    /// Resumes the pending continuation exactly once; every later call is a
    /// no-op. Resuming a continuation twice is undefined behaviour, and there
    /// are four things here that can each believe they finished first.
    private func finish(_ result: Result<GeoPoint, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: finish(.failure(Denied()))
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        finish(.success(GeoPoint(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }
}
