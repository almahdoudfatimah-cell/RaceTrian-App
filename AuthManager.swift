//
//  AuthManager.swift
//  RaceTrian
//
//  Created on 10/14/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var isGuest: Bool = true
    @Published var currentEmail: String?
    @Published var currentUser: User?
    
    private init() {
        loadAuthState()
    }
    
    // MARK: - Authentication State
    
    private func loadAuthState() {
        isGuest = UserDefaults.standard.bool(forKey: "isGuestUser")
        currentEmail = UserDefaults.standard.string(forKey: "userEmail")
        isAuthenticated = !isGuest && currentEmail != nil
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws {
        // TODO: Implement your sign-in logic with backend
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Store authentication state
        UserDefaults.standard.set(email, forKey: "userEmail")
        UserDefaults.standard.set(false, forKey: "isGuestUser")
        
        currentEmail = email
        isGuest = false
        isAuthenticated = true
    }

    func signUp(email: String, password: String) async throws {
        // The backend account-creation request belongs here. Until it is
        // connected, keep local authentication behavior consistent with sign in.
        try await signIn(email: email, password: password)
    }

    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { throw PasswordResetError.invalidEmail }

        let environment = ProcessInfo.processInfo.environment
        let projectURLString = environment["COACH_SUPABASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "CoachSupabaseURL") as? String ?? ""
        let publicKey = environment["COACH_SUPABASE_PUBLIC_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "CoachSupabasePublicKey") as? String ?? ""
        guard let projectURL = URL(string: projectURLString),
              projectURL.scheme == "https",
              !publicKey.isEmpty else {
            throw PasswordResetError.notConfigured
        }

        var request = URLRequest(url: projectURL.appendingPathComponent("auth/v1/recover"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(publicKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(publicKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": normalized])

        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PasswordResetError.network
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasswordResetError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PasswordResetError.requestFailed
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        // Clear authentication state
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.set(true, forKey: "isGuestUser")
        
        currentEmail = nil
        isGuest = true
        isAuthenticated = false
        currentUser = nil
    }
    
    // MARK: - Guest Mode
    
    func continueAsGuest() {
        UserDefaults.standard.set(true, forKey: "isGuestUser")
        isGuest = true
        isAuthenticated = false
    }
    
    // MARK: - Reset (Debug)
    
    func resetToOnboarding() {
        // Clear all user data
        signOut()
        
        // Reset onboarding state
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        
        // You might need to trigger a navigation reset in your app
        // This could be done through a notification or a published property
        NotificationCenter.default.post(name: NSNotification.Name("ResetToOnboarding"), object: nil)
    }
}

private enum PasswordResetError: LocalizedError {
    case invalidEmail
    case notConfigured
    case network
    case invalidResponse
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Enter your account email."
        case .notConfigured:
            "Password reset is not configured. Please contact support."
        case .network:
            "Unable to connect. Check your internet connection and try again."
        case .invalidResponse, .requestFailed:
            "The reset email could not be sent. Please try again later."
        }
    }
}

// MARK: - User Model

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    
    // Add any other user properties you need
}
