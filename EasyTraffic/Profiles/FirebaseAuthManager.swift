//
//  FirebaseAuthManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 11/23/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class FirebaseAuthManager: ObservableObject {
    static let shared = FirebaseAuthManager()
    
    @Published var currentFirebaseUser: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var authError: String?
    
    private let auth = Auth.auth()
    
    private init() {
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentFirebaseUser = user
                self?.isAuthenticated = user != nil
                
                if let user = user {
                    print("Firebase user signed in:", user.email ?? "no email")
                } else {
                    print("No Firebase user signed in")
                }
            }
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            print("User created:", result.user.uid)
            return result.user
        } catch {
            print("Sign up error:", error)
            throw error
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            print("User signed in:", result.user.uid)
            return result.user
        } catch {
            print("Sign in error:", error)
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        do {
            try auth.signOut()
            print("User signed out")
        } catch {
            print("Sign out error:", error)
            throw error
        }
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = currentFirebaseUser else {
            throw NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        
        try await user.delete()
        print("User account deleted")
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
        print("Password reset email sent")
    }
}
