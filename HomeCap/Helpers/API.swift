//
//  API.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 19.04.2025.
//

import Foundation
import MobileCoreServices  // Needed for MIME type lookup, or define manually

// Add response structs for single unit operations if needed (optional but good practice)
struct SingleUnitResponse: Codable {
    let message: String
    let unit: Unit
}
// Add basic message response struct
struct MessageResponse: Codable {
    let message: String
}

class API {
    static let shared = API()
    // Ensure this baseURL points to the correct API root
    private let baseURL = URL(string: "https://gettwin.ai/api")!
    private let session: URLSession

    private var sessionToken: String? {
        get { UserDefaults.standard.string(forKey: "sessionToken") }
        set { UserDefaults.standard.setValue(newValue, forKey: "sessionToken") }
    }

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30  // Example: 30 second timeout
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Login and then fetch the User details.
    func login(
        email: String,
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent("login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                let data = data,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                // Try to parse error message from backend if available
                var errorMessage = "Login failed"
                if let responseData = data,
                    let errorDict = try? JSONSerialization.jsonObject(
                        with: responseData
                    ) as? [String: Any],
                    let msg = errorDict["message"] as? String
                {
                    errorMessage = msg
                } else if let responseData = data,
                    let errorString = String(
                        data: responseData,
                        encoding: .utf8
                    ), !errorString.isEmpty
                {  // Basic error string
                    errorMessage += ": \(errorString)"
                }
                let err = NSError(
                    domain: "APIError",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                completion(.failure(err))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                    let token = json["token"] as? String
                {
                    self.sessionToken = token
                    // Now fetch the user record
                    self.fetchUser { userResult in
                        switch userResult {
                        case .success:
                            completion(.success(()))
                        case .failure(let fetchError):
                            self.sessionToken = nil  // Clear token if fetch fails
                            completion(.failure(fetchError))
                        }
                    }
                } else {
                    let parseErr = NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Invalid login response format"
                        ]
                    )
                    completion(.failure(parseErr))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Register and then fetch the User details.
    func register(
        name: String,
        email: String,
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent("register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "password": password,
            "password_confirmation": password,  // Assuming backend requires confirmation
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                let data = data,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                var errorMessage = "Registration failed"
                if let responseData = data,
                    let errorDict = try? JSONSerialization.jsonObject(
                        with: responseData
                    ) as? [String: Any],
                    let msg = errorDict["message"] as? String
                {
                    errorMessage = msg
                } else if let responseData = data,
                    let errorString = String(
                        data: responseData,
                        encoding: .utf8
                    ), !errorString.isEmpty
                {
                    errorMessage += ": \(errorString)"
                }
                let err = NSError(
                    domain: "APIError",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                completion(.failure(err))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                    let token = json["token"] as? String
                {
                    self.sessionToken = token
                    self.fetchUser { userResult in  // Fetch user after registration
                        switch userResult {
                        case .success:
                            completion(.success(()))
                        case .failure(let fetchError):
                            self.sessionToken = nil  // Clear token if fetch fails
                            completion(.failure(fetchError))
                        }
                    }
                } else {
                    let parseErr = NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Invalid register response format"
                        ]
                    )
                    completion(.failure(parseErr))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Build an authorized request using the stored token.
    /// Creates an authorized request if a session token exists.
    internal func authorizedRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        contentType: String = "application/json"
    ) -> URLRequest? {
        guard let token = sessionToken else {
            Log.warning("Authorization Error: No session token found.")
            return nil
        }
        // Ensure endpoint doesn't start with '/' if baseURL doesn't end with '/'
        let path =
            endpoint.starts(with: "/") ? String(endpoint.dropFirst()) : endpoint
        let fullURL = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: fullURL)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")  // Expect JSON response

        if let b = body {
            request.httpBody = b
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")  // Set content type for body
        }

        return request
    }

    /// Validate the stored token.
    func validateToken(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let req = authorizedRequest(endpoint: "validate-token") else {
            let err = NSError(
                domain: "APIError",
                code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No session token available for validation."
                ]
            )
            completion(.failure(err))
            return
        }
        session.dataTask(with: req) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let err = NSError(
                    domain: "APIError",
                    code: code,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Token validation failed (Code: \(code))"
                    ]
                )
                self.sessionToken = nil  // Clear invalid token
                completion(.failure(err))
                return
            }
            completion(.success(()))  // Token is valid
        }.resume()
    }

    /// Fetch the current User from `/user`.
    func fetchUser(completion: @escaping (Result<User, Error>) -> Void) {
        guard let req = authorizedRequest(endpoint: "user") else {
            let err = NSError(
                domain: "APIError",
                code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No session token available to fetch user."
                ]
            )
            completion(.failure(err))
            return
        }
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                let d = data,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let err = NSError(
                    domain: "APIError",
                    code: code,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Fetch user failed (Code: \(code))"
                    ]
                )
                completion(.failure(err))
                return
            }
            do {
                let user = try JSONDecoder().decode(User.self, from: d)
                completion(.success(user))
            } catch {
                print("Failed to decode User: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    // --- ADDED Upload Function (JSON + USDZ) ---
    /// Uploads scan results (JSON metadata and USDZ model) using multipart/form-data.
    func uploadScanResults(
        endpoint: String,
        name: String,
        latitude: Double?,
        longitude: Double?,
        jsonFileName: String = "scan_metadata.json",
        jsonData: Data,
        modelFileName: String = "scan_model.usdz",
        modelData: Data,  // USDZ data
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard
            var request = authorizedRequest(
                endpoint: endpoint,
                method: "POST",
                contentType: "multipart/form-data; boundary=\(boundary)"
            )
        else {
            let err = NSError(
                domain: "APIError",
                code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Authorization token missing for upload."
                ]
            )
            completion(.failure(err))
            return
        }

        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        let crlf = "\r\n"
        let crlfData = crlf.data(using: .utf8)!  // Pre-encode CRLF for appending

        // Name field part
        body.append(boundaryPrefix)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n")  // Header line 1
        body.append("\r\n")  // Empty line separating headers from body
        body.append(name)  // Body of the part
        body.append(crlfData)  // End of part data

        // --- NEW: Add Latitude field (Optional) ---
        if let lat = latitude {
            body.append(boundaryPrefix)
            body.append(
                "Content-Disposition: form-data; name=\"latitude\"\r\n\r\n"
            )
            body.append("\(lat)")  // Convert Double to String
            body.append(crlfData)
        }
        // --- END NEW ---

        // --- NEW: Add Longitude field (Optional) ---
        if let lon = longitude {
            body.append(boundaryPrefix)
            body.append(
                "Content-Disposition: form-data; name=\"longitude\"\r\n\r\n"
            )
            body.append("\(lon)")  // Convert Double to String
            body.append(crlfData)
        }
        // --- END NEW ---

        // JSON Metadata Part
        body.append(boundaryPrefix)
        body.append(
            "Content-Disposition: form-data; name=\"metadata_json\"; filename=\"\(jsonFileName)\"\r\n"
        )  // Has .json filename
        body.append("Content-Type: application/json\r\n")  // Standard JSON MIME type
        body.append("\r\n")  // Empty line separating headers from body
        body.append(jsonData)  // Body of the part (JSON data)
        body.append(crlfData)  // End of part data

        // USDZ Model Part
        body.append(boundaryPrefix)
        body.append(
            "Content-Disposition: form-data; name=\"model\"; filename=\"\(modelFileName)\"\r\n"
        )  // Has .usdz filename
        body.append("Content-Type: application/octet-stream\r\n")
        body.append("\r\n")  // Empty line separating headers from body
        body.append(modelData)  // Body of the part (USDZ data)
        body.append(crlfData)  // End of part data

        // Final Boundary
        body.append("--\(boundary)--\r\n")  // Note the extra -- at the end

        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        // Ensure the main Content-Type header for the request is still correct
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Upload network error: \(error)")
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                let err = NSError(
                    domain: "APIError",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Invalid server response during upload."
                    ]
                )
                completion(.failure(err))
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "Upload failed: \(httpResponse.statusCode)"
                if let responseData = data,
                    let errorString = String(
                        data: responseData,
                        encoding: .utf8
                    ), !errorString.isEmpty
                {
                    errorMessage += "\nServer: \(errorString)"
                }
                let err = NSError(
                    domain: "APIError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                print(errorMessage)
                completion(.failure(err))
                return
            }
            print("Upload successful (Status Code: \(httpResponse.statusCode))")
            completion(.success(()))
        }.resume()
    }

    /// Fetches the list of scans for the authenticated user.
    func fetchScans(completion: @escaping (Result<[Scan], Error>) -> Void) {
        guard let request = authorizedRequest(endpoint: "scans", method: "GET")
        else {
            let err = NSError(
                domain: "APIError",
                code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Authorization token missing for fetching scans."
                ]
            )
            completion(.failure(err))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Fetch scans network error: \(error)")
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let err = NSError(
                    domain: "APIError",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Invalid server response when fetching scans."
                    ]
                )
                completion(.failure(err))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage =
                    "Fetch scans failed: \(httpResponse.statusCode)"
                if let responseData = data,
                    let errorString = String(
                        data: responseData,
                        encoding: .utf8
                    ), !errorString.isEmpty
                {
                    errorMessage += "\nServer: \(errorString)"
                }
                let err = NSError(
                    domain: "APIError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                print(errorMessage)
                completion(.failure(err))
                return
            }

            guard let data = data else {
                let err = NSError(
                    domain: "APIError",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "No data received when fetching scans."
                    ]
                )
                completion(.failure(err))
                return
            }

            // Debug: Print raw JSON string
            // print("Raw JSON Scans: \(String(data: data, encoding: .utf8) ?? "Invalid UTF-8")")

            do {
                // *** MODIFICATION START ***
                // Decode the JSON data using the ScanResponse wrapper struct
                let decoder = JSONDecoder()
                let scanResponse = try decoder.decode(
                    ScanResponse.self,
                    from: data
                )
                print(
                    "Successfully decoded ScanResponse containing \(scanResponse.scans.count) scans."
                )
                // Pass the extracted array of scans to the completion handler
                completion(.success(scanResponse.scans))
                // *** MODIFICATION END ***
            } catch {
                print("Failed to decode ScanResponse: \(error)")
                // Print decoding errors for debugging
                if let decodingError = error as? DecodingError {
                    print("Decoding Error Details: \(decodingError)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    /// --- NEW: Delete a specific scan ---
    func deleteScan(
        scanId: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Endpoint uses DELETE /scans/{id} - Note: Your route shows {scan} but uses {id} in controller? Assuming {id} based on controller method signature. Verify this.
        // If the route is truly `/scans/{scan}` (expecting the model instance, which isn't standard for DELETE by ID), the backend route needs fixing.
        // Assuming standard DELETE by ID: /scans/{id}
        guard
            let request = authorizedRequest(
                endpoint: "scans/\(scanId)",
                method: "DELETE"
            )
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Authorization token missing."
                        ]
                    )
                )
            )
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errMsg = self.parseErrorMessage(
                    data: data,
                    fallback: "Delete scan failed"
                )
                completion(
                    .failure(
                        NSError(
                            domain: "APIError",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: errMsg]
                        )
                    )
                )
                return
            }
            completion(.success(()))
        }.resume()
    }

    /// --- NEW: Fetch Units and associated Scans ---
    func fetchUnitsAndScans(
        completion: @escaping (Result<(units: [Unit], scans: [Scan]), Error>) ->
            Void
    ) {
        guard let request = authorizedRequest(endpoint: "units", method: "GET")
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Authorization token missing."
                        ]
                    )
                )
            )
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse, let data = data,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errMsg = self.parseErrorMessage(
                    data: data,
                    fallback: "Fetch units failed"
                )
                completion(
                    .failure(
                        NSError(
                            domain: "APIError",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: errMsg]
                        )
                    )
                )
                return
            }

            do {
                let decoder = JSONDecoder()
                let unitsResponse = try decoder.decode(
                    UnitsResponse.self,
                    from: data
                )
                completion(
                    .success(
                        (units: unitsResponse.units, scans: unitsResponse.scans)
                    )
                )
            } catch {
                print("Failed to decode UnitsResponse: \(error)")
                if let decodingError = error as? DecodingError {
                    print("Decoding Error Details: \(decodingError)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    /// --- NEW: Create a new Unit ---
    //    func createUnit(
    //        unitData: [String: Any],
    //        completion: @escaping (Result<Unit, Error>) -> Void
    //    ) {
    //        guard let body = try? JSONSerialization.data(withJSONObject: unitData)
    //        else {
    //            completion(
    //                .failure(
    //                    NSError(
    //                        domain: "APIError",
    //                        code: 0,
    //                        userInfo: [
    //                            NSLocalizedDescriptionKey:
    //                                "Failed to encode unit data."
    //                        ]
    //                    )
    //                )
    //            )
    //            return
    //        }
    //        guard
    //            let request = authorizedRequest(
    //                endpoint: "units",
    //                method: "POST",
    //                body: body
    //            )
    //        else {
    //            completion(
    //                .failure(
    //                    NSError(
    //                        domain: "APIError",
    //                        code: 0,
    //                        userInfo: [
    //                            NSLocalizedDescriptionKey:
    //                                "Authorization token missing."
    //                        ]
    //                    )
    //                )
    //            )
    //            return
    //        }
    //
    //        session.dataTask(with: request) { data, response, error in
    //            if let error = error {
    //                completion(.failure(error))
    //                return
    //            }
    //            guard let http = response as? HTTPURLResponse, let data = data,
    //                (200...299).contains(http.statusCode)
    //            else {
    //                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
    //                let errMsg = self.parseErrorMessage(
    //                    data: data,
    //                    fallback: "Create unit failed"
    //                )
    //                completion(
    //                    .failure(
    //                        NSError(
    //                            domain: "APIError",
    //                            code: code,
    //                            userInfo: [NSLocalizedDescriptionKey: errMsg]
    //                        )
    //                    )
    //                )
    //                return
    //            }
    //
    //            do {
    //                // Expecting {"message": "...", "unit": {...}}
    //                let decoder = JSONDecoder()
    //                let unitResponse = try decoder.decode(
    //                    SingleUnitResponse.self,
    //                    from: data
    //                )
    //                completion(.success(unitResponse.unit))
    //            } catch {
    //                print("Failed to decode SingleUnitResponse (Create): \(error)")
    //                completion(.failure(error))
    //            }
    //        }.resume()
    //    }

    /// Creates a new Unit. Returns Result<Unit, APIError>
    func createUnit(
        unitData: [String: Any],
        completion: @escaping (Result<Unit, APIError>) -> Void
    ) {  // << MODIFIED Error type
        guard let body = try? JSONSerialization.data(withJSONObject: unitData)
        else {
            completion(
                .failure(
                    .encodingError(
                        NSError(
                            domain: "API",
                            code: 1,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Failed to encode unit data."
                            ]
                        )
                    )
                )
            )  // Pass underlying error if helpful
            return
        }
        guard
            let request = authorizedRequest(
                endpoint: "units",
                method: "POST",
                body: body
            )
        else {
            completion(
                .failure(
                    .authenticationError(
                        "Authorization token missing or invalid."
                    )
                )
            )
            return
        }

        Log.debug("API: Creating Unit...")
        let task = session.dataTask(with: request) { data, response, error in  // Use injected session
            // Handle Network Error
            if let error = error {
                Log.error(
                    "API Error (Create Unit - Network): \(error.localizedDescription)"
                )
                completion(.failure(.networkError(error)))
                return
            }

            // Check Response Type
            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error(
                    "API Error (Create Unit): Invalid response type received."
                )
                completion(.failure(.other("Invalid response from server.")))
                return
            }

            Log.info(
                "API: Create Unit response status: \(httpResponse.statusCode)"
            )
            let responseData = data ?? Data()  // Use empty data if nil

            // --- CHECK FOR SPECIFIC ERRORS FIRST ---
            if httpResponse.statusCode == 401 {  // Unauthorized
                Log.warning(
                    "API Error (Create Unit): Received 401 Unauthorized."
                )
                completion(
                    .failure(.authenticationError("Invalid session token."))
                )
                return
            }
            if httpResponse.statusCode == 403 {  // Forbidden - Use this for Subscription Required
                Log.warning(
                    "API Error (Create Unit): Received 403 Forbidden - Subscription Required."
                )
                completion(.failure(.subscriptionRequired))  // << RETURN SPECIFIC ERROR
                return
            }
            // --- END SPECIFIC ERRORS ---

            // Check for general server/client errors (4xx, 5xx) excluding ones handled above
            guard (200...299).contains(httpResponse.statusCode) else {
                let errMsg = self.parseErrorMessage(
                    data: responseData,
                    fallback: "Failed to create unit"
                )
                Log.error(
                    "API Error (Create Unit - Server/Client Error \(httpResponse.statusCode)): \(errMsg)"
                )
                completion(
                    .failure(.serverError(httpResponse.statusCode, errMsg))
                )
                return
            }

            // Attempt to Decode Success Response
            do {
                let decoder = JSONDecoder()
                // Assuming backend still sends SingleUnitResponse on success (201 Created usually)
                let unitResponse = try decoder.decode(
                    SingleUnitResponse.self,
                    from: responseData
                )
                Log.info(
                    "API: Successfully created Unit ID: \(unitResponse.unit.id)"
                )
                completion(.success(unitResponse.unit))
            } catch {
                Log.error(
                    "API Error (Create Unit - Decoding): \(error.localizedDescription)"
                )
                // Log raw response data for debugging if decoding fails
                // Log.debug("Raw response data: \(String(data: responseData, encoding: .utf8) ?? "Invalid data")")
                completion(.failure(.decodingError(error)))
            }
        }
        task.resume()
    }

    /// --- NEW: Update an existing Unit ---
    func updateUnit(
        unitId: Int,
        unitData: [String: Any],
        completion: @escaping (Result<Unit, Error>) -> Void
    ) {
        guard let body = try? JSONSerialization.data(withJSONObject: unitData)
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Failed to encode unit data."
                        ]
                    )
                )
            )
            return
        }
        // Endpoint uses PUT /units/{unit}
        guard
            let request = authorizedRequest(
                endpoint: "units/\(unitId)",
                method: "PUT",
                body: body
            )
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Authorization token missing."
                        ]
                    )
                )
            )
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse, let data = data,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errMsg = self.parseErrorMessage(
                    data: data,
                    fallback: "Update unit failed"
                )
                completion(
                    .failure(
                        NSError(
                            domain: "APIError",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: errMsg]
                        )
                    )
                )
                return
            }

            do {
                // Expecting {"message": "...", "unit": {...}}
                let decoder = JSONDecoder()
                let unitResponse = try decoder.decode(
                    SingleUnitResponse.self,
                    from: data
                )
                completion(.success(unitResponse.unit))
            } catch {
                print("Failed to decode SingleUnitResponse (Update): \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    /// --- NEW: Delete a specific Unit ---
    func deleteUnit(
        unitId: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Endpoint uses DELETE /units/{unit}
        guard
            let request = authorizedRequest(
                endpoint: "units/\(unitId)",
                method: "DELETE"
            )
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Authorization token missing."
                        ]
                    )
                )
            )
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errMsg = self.parseErrorMessage(
                    data: data,
                    fallback: "Delete unit failed"
                )
                completion(
                    .failure(
                        NSError(
                            domain: "APIError",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: errMsg]
                        )
                    )
                )
                return
            }
            completion(.success(()))
        }.resume()
    }

    // MARK: - Profile Functions

    /// --- NEW: Delete user profile ---
    func deleteProfile(
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard
            let body = try? JSONSerialization.data(withJSONObject: [
                "password": password
            ])
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Failed to encode password."
                        ]
                    )
                )
            )
            return
        }
        // Endpoint uses DELETE /profile
        guard
            let request = authorizedRequest(
                endpoint: "profile",
                method: "DELETE",
                body: body
            )
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Authorization token missing."
                        ]
                    )
                )
            )
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                // Backend might return validation errors in specific format, check if needed
                let errMsg = self.parseErrorMessage(
                    data: data,
                    fallback: "Delete profile failed"
                )
                completion(
                    .failure(
                        NSError(
                            domain: "APIError",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: errMsg]
                        )
                    )
                )
                return
            }
            // On success, backend logs out, so we don't receive user/token data
            completion(.success(()))
        }.resume()
    }

    func fetchStats(
        completion: @escaping (Result<StatsResponse, Error>) -> Void
    ) {
        // Endpoint is GET /stats
        guard let request = authorizedRequest(endpoint: "stats", method: "GET")
        else {
            completion(
                .failure(
                    NSError(
                        domain: "APIError",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Authorization token missing."
                        ]
                    )
                )
            )
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse, let data = data,
                (200...299).contains(http.statusCode)
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errMsg = self.parseErrorMessage(
                    data: data,
                    fallback: "İstatistikler alınamadı"
                )  // Fetch stats failed (Turkish)
                completion(
                    .failure(
                        NSError(
                            domain: "APIError",
                            code: code,
                            userInfo: [NSLocalizedDescriptionKey: errMsg]
                        )
                    )
                )
                return
            }

            // Debug: Print raw JSON
            // print("Raw Stats JSON: \(String(data: data, encoding: .utf8) ?? "Invalid UTF-8")")

            do {
                let decoder = JSONDecoder()
                let statsResponse = try decoder.decode(
                    StatsResponse.self,
                    from: data
                )
                print("Successfully decoded StatsResponse.")
                completion(.success(statsResponse))
            } catch {
                print("Failed to decode StatsResponse: \(error)")
                if let decodingError = error as? DecodingError {
                    print("Decoding Error Details: \(decodingError)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Subscription Verification (NEW)

    /// Sends transaction IDs to the backend for server-side validation with Apple.
    /// - Parameters:
    ///   - transactionId: The unique ID of the transaction from StoreKit.
    ///   - originalTransactionId: The original transaction ID for the subscription group from StoreKit.
    /// - Returns: `true` if the backend successfully verified and updated the status, `false` otherwise.
    @discardableResult  // Result can be ignored if only used to trigger backend update
    func verifySubscription(
        transactionId: String,
        originalTransactionId: String
    ) async -> Bool {

        let endpoint = "subscriptions/verify"
        let body: [String: String] = [
            "transactionId": transactionId,
            "originalTransactionId": originalTransactionId,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body)
        else {
            Log.error(
                "API Error: Failed to encode subscription verification body."
            )
            // Consider how to report this failure if needed
            return false
        }

        guard
            let request = authorizedRequest(
                endpoint: endpoint,
                method: "POST",
                body: jsonData
            )
        else {
            Log.error(
                "API Error: Cannot create authorized request for subscription verification (token missing?)."
            )
            // Might indicate user is logged out unexpectedly
            return false
        }

        Log.info(
            "API: Calling backend to verify TxID: \(transactionId), OriginalTxID: \(originalTransactionId)"
        )

        do {
            let (data, response) = try await session.data(for: request)  // Use injected session

            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error(
                    "API Error: Invalid response type received for subscription verification."
                )
                return false
            }

            Log.info(
                "API: Verify subscription response status: \(httpResponse.statusCode)"
            )

            if (200...299).contains(httpResponse.statusCode) {
                Log.info("API: Backend verification successful.")
                // Optional: Decode success message if backend sends one
                return true
            } else {
                // Log specific error from backend if possible
                let errorMessage = self.parseErrorMessage(
                    data: data,
                    fallback: "Subscription verification failed on backend."
                )
                Log.error(
                    "API Error: Backend verification failed (\(httpResponse.statusCode)): \(errorMessage)"
                )
                return false
            }
        } catch {
            // Handle potential network errors (timeout, no connection etc.)
            Log.error(
                "API Error: Network error during subscription verification: \(error.localizedDescription)"
            )
            return false
        }
    }

    // MARK: - Helpers
    /// --- NEW: Helper to parse common error messages ---
    internal func parseErrorMessage(data: Data?, fallback: String) -> String {
        guard let data = data, !data.isEmpty else { return fallback }
        // Attempt to decode standard Laravel JSON error { "message": "..." }
        if let json = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        {
            if let message = json["message"] as? String {
                // Handle Laravel validation errors specifically if present
                if let errors = json["errors"] as? [String: [String]],
                    let firstError = errors.first?.value.first
                {
                    return "\(message): \(firstError)"  // Combine main message and first validation error
                }
                return message  // Return main message
            }
        }
        // Fallback to raw string if JSON parsing fails or has unknown structure
        return String(data: data, encoding: .utf8) ?? fallback
    }
}

enum APIError: Error, LocalizedError {
    case subscriptionRequired  // Specific error for paywall trigger
    case authenticationError(String)  // e.g., Token invalid/expired
    case networkError(Error)  // Underlying network issue
    case serverError(Int, String)  // Specific HTTP error from server
    case decodingError(Error)  // Failed to parse response
    case encodingError(Error)  // Failed to encode request body
    case invalidData  // Missing expected data
    case other(String)  // General/unknown error

    var errorDescription: String? {
        switch self {
        case .subscriptionRequired:
            // This specific message might be checked in the ViewModel
            return
                "Bu işlem için aktif bir abonelik veya deneme süresi gereklidir."
        case .authenticationError(let message):
            return "Yetkilendirme Hatası: \(message)"
        case .networkError(let error):
            return "Ağ Hatası: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Sunucu Hatası (\(code)): \(message)"
        case .decodingError(let error):
            return "Veri Çözümleme Hatası: \(error.localizedDescription)"
        case .encodingError:
            return "İstek oluşturulamadı."
        case .invalidData:
            return "Sunucudan geçersiz veya eksik veri alındı."
        case .other(let message):
            return message
        }
    }
}

// Helper extension
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

struct Log {
    static func info(_ message: String) { print("ℹ️ INFO: \(message)") }
    static func debug(_ message: String) { print("🛠️ DEBUG: \(message)") }
    static func warning(_ message: String) { print("⚠️ WARN: \(message)") }
    static func error(_ message: String) { print("❌ ERROR: \(message)") }
}
