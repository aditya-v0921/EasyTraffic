//
//  FirebaseUserManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 11/23/25.
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

class FirebaseUserManager: ObservableObject {
    static let shared = FirebaseUserManager()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    @Published var users: [User] = []
    @Published var currentUser: User?
    
    private var userListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Create User
    
    func createUser(name: String, email: String, password: String, role: UserRole = .parent) async throws -> User {
        // 1. Create Firebase Auth account
        let firebaseUser = try await FirebaseAuthManager.shared.signUp(email: email, password: password)
        
        // 2. Create User document in Firestore
        let user = User(
            id: UUID(uuidString: firebaseUser.uid) ?? UUID(),
            name: name,
            email: email,
            role: role,
            familyId: nil
        )
        
        try await saveUser(user)
        
        DispatchQueue.main.async {
            self.currentUser = user
        }
        
        return user
    }
    
    // MARK: - Save User
    
    func saveUser(_ user: User) async throws {
        let docRef = db.collection(usersCollection).document(user.id.uuidString)
        
        do {
            try docRef.setData(from: user)
            print("User saved to Firestore:", user.id)
            
            // Update local cache
            DispatchQueue.main.async {
                if let index = self.users.firstIndex(where: { $0.id == user.id }) {
                    self.users[index] = user
                } else {
                    self.users.append(user)
                }
            }
        } catch {
            print("Failed to save user:", error)
            throw error
        }
    }
    
    // MARK: - Fetch User
    
    func fetchUser(by id: UUID) async throws -> User? {
        let docRef = db.collection(usersCollection).document(id.uuidString)
        
        do {
            let user = try await docRef.getDocument(as: User.self)
            print("User fetched:", user.id)
            return user
        } catch {
            print("Failed to fetch user:", error)
            return nil
        }
    }
    
    // MARK: - Fetch User by Email
    
    func fetchUser(by email: String) async throws -> User? {
        let query = db.collection(usersCollection)
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
        
        do {
            let snapshot = try await query.getDocuments()
            guard let document = snapshot.documents.first else {
                return nil
            }
            
            let user = try document.data(as: User.self)
            print("✅ User fetched by email:", user.id)
            return user
        } catch {
            print("❌ Failed to fetch user by email:", error)
            return nil
        }
    }
    
    // MARK: - Update User
    
    func updateUser(_ user: User) async throws {
        try await saveUser(user)
    }
    
    // MARK: - Delete User
    
    func deleteUser(_ user: User) async throws {
        let docRef = db.collection(usersCollection).document(user.id.uuidString)
        
        do {
            try await docRef.delete()
            print("User deleted from Firestore")
            
            DispatchQueue.main.async {
                self.users.removeAll { $0.id == user.id }
                if self.currentUser?.id == user.id {
                    self.currentUser = nil
                }
            }
        } catch {
            print("Failed to delete user:", error)
            throw error
        }
    }
    
    // MARK: - Listen to User Changes (Real-time)
    
    func listenToUser(_ userId: UUID) {
        userListener?.remove()
        
        let docRef = db.collection(usersCollection).document(userId.uuidString)
        
        userListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("User listener error:", error)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                print("User document doesn't exist")
                return
            }
            
            do {
                let user = try snapshot.data(as: User.self)
                DispatchQueue.main.async {
                    self.currentUser = user
                    print("User updated in real-time:", user.name)
                }
            } catch {
                print("Failed to decode user:", error)
            }
        }
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        userListener?.remove()
        userListener = nil
    }
    
    // MARK: - Sign In Existing User
    
    func signIn(email: String, password: String) async throws -> User {
        // 1. Sign in with Firebase Auth
        let firebaseUser = try await FirebaseAuthManager.shared.signIn(email: email, password: password)
        
        // 2. Fetch user from Firestore
        guard let user = try await fetchUser(by: UUID(uuidString: firebaseUser.uid) ?? UUID()) else {
            throw NSError(domain: "FirebaseUserManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found in database"])
        }
        
        // 3. Set as current user and start listening
        DispatchQueue.main.async {
            self.currentUser = user
        }
        listenToUser(user.id)
        
        return user
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try FirebaseAuthManager.shared.signOut()
        stopListening()
        
        DispatchQueue.main.async {
            self.currentUser = nil
        }
    }
    
    // MARK: - Get All Users (for family management)
    
    func fetchAllUsers() async throws -> [User] {
        let snapshot = try await db.collection(usersCollection).getDocuments()
        
        let users = snapshot.documents.compactMap { document -> User? in
            try? document.data(as: User.self)
        }
        
        DispatchQueue.main.async {
            self.users = users
        }
        
        print("Fetched \(users.count) users")
        return users
    }
    
    // MARK: - Local lookup helpers

    // Lookup by UUID
    func getUser(by id: UUID) -> User? {
            users.first { $0.id == id }
        }
        
    // Convenience: lookup by String UUID
    func getUser(by idString: String) -> User? {
            guard let uuid = UUID(uuidString: idString) else { return nil }
            return getUser(by: uuid)
        }

}
