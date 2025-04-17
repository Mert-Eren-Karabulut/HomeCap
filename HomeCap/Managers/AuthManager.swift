//
//  AuthManager.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 19.04.2025.
//

import SwiftUI

/// Our app’s single User model
struct User: Codable, Identifiable {  // Add Identifiable conformance
    let id: Int  // Add 'id' if your /api/user returns it
    let name: String
    let email: String
    var subscriptionTier: String?  // Add optional tier ('free', 'trial', 'premium')

    // Add CodingKeys to map JSON 'subscription_tier' from backend
    enum CodingKeys: String, CodingKey {
        case id  // Add if present
        case name
        case email
        case subscriptionTier = "subscription_tier"  // Match your backend JSON key
    }
}
/// Central auth state: validates stored token, performs login/logout, holds the User.
class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    private var sessionToken: String? {
        get { UserDefaults.standard.string(forKey: "sessionToken") }
        set { UserDefaults.standard.setValue(newValue, forKey: "sessionToken") }
    }
    init() {
        // On app launch, validate any existing token
        API.shared.validateToken { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    // Token is good → fetch the user record
                    API.shared.fetchUser { fetchResult in
                        DispatchQueue.main.async {
                            switch fetchResult {
                            case .success(let user):
                                self.currentUser = user
                                self.isLoggedIn = true
                            case .failure:
                                self.isLoggedIn = false
                            }
                        }
                    }
                case .failure:
                    self.isLoggedIn = false
                }
            }
        }
        @MainActor
        func refreshUserProfile() async {
            guard isLoggedIn, sessionToken != nil else { return }  // Only refresh if logged in

            print("AuthManager: Refreshing user profile...")
            API.shared.fetchUser { result in
                DispatchQueue.main.async {  // Ensure update on main thread
                    switch result {
                    case .success(let user):
                        print(
                            "AuthManager: User profile refreshed successfully. Tier: \(user.subscriptionTier ?? "nil")"
                        )
                        self.currentUser = user  // Update published property
                    case .failure(let error):
                        print(
                            "AuthManager: Failed to refresh user profile: \(error.localizedDescription)"
                        )
                    // Decide if you want to log out on fetch failure or just keep old data
                    // self.logOut()
                    }
                }
            }
        }
    }

    /// Perform login and populate `currentUser` on success.
    func logIn(
        email: String,
        password: String,
        completion: @escaping (Error?) -> Void
    ) {
        API.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    API.shared.fetchUser { fetchResult in
                        DispatchQueue.main.async {
                            switch fetchResult {
                            case .success(let user):
                                self.currentUser = user
                                self.isLoggedIn = true
                                completion(nil)
                            case .failure(let error):
                                completion(error)  // now uses the failure-bound `error`
                            }
                        }
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }

    /// Perform Register and populate current user
    func register(
        name: String,
        email: String,
        password: String,
        completion: @escaping (Error?) -> Void
    ) {
        API.shared.register(name: name, email: email, password: password) {
            result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    API.shared.fetchUser { fetchResult in
                        DispatchQueue.main.async {
                            switch fetchResult {
                            case .success(let user):
                                self.currentUser = user
                                self.isLoggedIn = true
                                completion(nil)
                            case .failure(let error):
                                completion(error)  // now uses the failure-bound `error`
                            }
                        }
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }

    /// Clear token and user when logging out.
    func logOut() {
        UserDefaults.standard.removeObject(forKey: "sessionToken")
        isLoggedIn = false
        currentUser = nil
    }

    /// Calls the API to delete the user's account and logs out locally on success.
    func deleteAccount(
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        API.shared.deleteProfile(password: password) { result in
            DispatchQueue.main.async {  // Switch to main thread
                switch result {
                case .success:
                    print(
                        "Account deletion successful on server. Logging out locally."
                    )
                    // Call logout to clear local state AFTER successful deletion
                    self.logOut()
                    completion(.success(()))
                case .failure(let error):
                    print("Account deletion failed: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
}
