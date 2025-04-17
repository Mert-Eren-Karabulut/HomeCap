//
//  LocationManager.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 2.05.2025.
//


// LocationManager.swift
import Foundation
import CoreLocation
import Combine // Needed for ObservableObject if not using @Observable

// Make sure your project's minimum deployment target supports ObservableObject (iOS 13+)
// or @Observable (iOS 17+)

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    // Published properties for SwiftUI views to observe
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationError: Error?

    override init() {
        authorizationStatus = manager.authorizationStatus // Get initial status
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters // Aim for ~10m precision
        print("LocationManager Initialized. Status: \(authorizationStatus.description)")
    }

    /// Checks current status and requests location access if needed, then requests location.
    func requestLocationAccessOrUpdate() {
        print("Requesting location access or update...")
        switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                print("Location authorized. Requesting location...")
                manager.requestLocation() // Request a one-time location update
            case .notDetermined:
                print("Location not determined. Requesting When In Use authorization...")
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                print("Location access denied or restricted.")
                // Optionally set an error or state indicating permission issue
                self.locationError = NSError(domain: "LocationError", code: CLError.denied.rawValue, userInfo: [NSLocalizedDescriptionKey: "Konum izni reddedildi veya kısıtlandı."])
            @unknown default:
                print("Unknown location authorization status.")
                manager.requestWhenInUseAuthorization() // Request anyway for future cases
        }
    }

    // MARK: - CLLocationManagerDelegate Methods

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Update published status when it changes
        authorizationStatus = manager.authorizationStatus
        print("Location authorization status changed to: \(authorizationStatus.description)")
        // If permission was just granted, request location now
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            print("Authorization granted. Requesting location...")
            manager.requestLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
             self.locationError = NSError(domain: "LocationError", code: CLError.denied.rawValue, userInfo: [NSLocalizedDescriptionKey: "Konum izni reddedildi veya kısıtlandı."])
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // requestLocation typically delivers one result, but handle array just in case
        if let location = locations.last {
             print("Received location: \(location.coordinate), Accuracy: \(location.horizontalAccuracy)m")
             // Check if accuracy is acceptable (<50m is usually good enough quickly)
             if location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 50 { // Accept readings under 50m accuracy
                  lastKnownLocation = location.coordinate
                  locationError = nil // Clear previous errors if successful
                  print("Stored location with acceptable accuracy.")
             } else if lastKnownLocation == nil {
                  // Store less accurate location only if we don't have one yet
                  lastKnownLocation = location.coordinate
                  print("Stored location with lower accuracy (\(location.horizontalAccuracy)m) as initial value.")
             }
        } else {
             print("Location update received, but no locations in array.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        locationError = error // Publish the error
        // Handle specific errors like kCLErrorDenied if needed elsewhere
        // Note: kCLErrorLocationUnknown might be transient, don't necessarily stop trying.
    }
}

// Helper to get description for CLAuthorizationStatus (optional)
extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default: return "Unknown"
        }
    }
}