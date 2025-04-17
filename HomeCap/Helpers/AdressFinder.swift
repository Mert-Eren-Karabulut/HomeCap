//
//  AdressFinder.swift
//  HomeCap
//
//

import CoreLocation
import SwiftUI

/// A utility that converts latitude & longitude into a human‑readable address.
struct AddressFinder {

    /// Performs reverse‑geocoding and returns the formatted address string via the completion handler.
    /// - Parameters:
    ///   - latitude:  Latitude as `Double`.
    ///   - longitude: Longitude as `Double`.
    ///   - completion: Closure that receives an optional address string. It is `nil` if
    ///                 no address could be resolved.
    static func getAddress(fromLatitude latitude: Double,
                           longitude: Double,
                           completion: @escaping (String?) -> Void) {

        let location  = CLLocation(latitude: latitude, longitude: longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocode failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }

            var components: [String] = []
            if let subLocality  = placemark.subLocality  { components.append(subLocality) }
            if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
            if let locality     = placemark.locality     { components.append(locality) }
            if let country      = placemark.country      { components.append(country) }
            if let postalCode   = placemark.postalCode   { components.append(postalCode) }

            let address = components.joined(separator: ", ")
            completion(address.isEmpty ? nil : address)
        }
    }
}

struct AddressTextView: View {
    let latitudeString: String?
    let longitudeString: String?
    @State private var address: String = ""

    var body: some View {
        Group {
            if let latStr = latitudeString,
               let lonStr = longitudeString,
               let lat = Double(latStr),
               let lon = Double(lonStr) {
                Text(address.isEmpty ? "Adres yükleniyor..." : address)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .onAppear {
                        AddressFinder.getAddress(fromLatitude: lat, longitude: lon) { result in
                            DispatchQueue.main.async {
                                address = result ?? "Adres bulunamadı"
                            }
                        }
                    }
            } else {
                Text("Lokasyon bilgisi eklenmedi.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}
