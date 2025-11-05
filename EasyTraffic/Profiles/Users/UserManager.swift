//
//  UserManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 10/29/25.
//

import Foundation

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var users: [User] = []
    @Published var currentUser: User?
    
    private let usersKey = "saved_users"
    private let currentUserKey = "current_user_id"
    
    private init() {
        loadUsers()
        loadCurrentUser()
    }
    
    // MARK: - User Management
    
    func createUser(name: String, email: String? = nil, role: UserRole = .parent) -> User {
        let newUser = User(name: name, email: email, role: role)
        users.append(newUser)
        saveUsers()
        
        // Set as current user if first user
        if users.count == 1 {
            setCurrentUser(newUser)
        }
        
        return newUser
    }
    
    func updateUser(_ user: User) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
            saveUsers()
            
            // Update current user if it's the same
            if currentUser?.id == user.id {
                currentUser = user
            }
        }
    }
    
    func deleteUser(_ user: User) {
        users.removeAll { $0.id == user.id }
        saveUsers()
        
        // If deleting current user, switch to another or nil
        if currentUser?.id == user.id {
            currentUser = users.first
            saveCurrentUser()
        }
    }
    
    func setCurrentUser(_ user: User) {
        var updatedUser = user
        updatedUser.updateLastActive()
        
        currentUser = updatedUser
        updateUser(updatedUser)
        saveCurrentUser()
    }
    
    func getUser(by id: UUID) -> User? {
        return users.first { $0.id == id }
    }
    
    // MARK: - Persistence (File-based JSON)
    
    private func saveUsers() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(users)
            UserDefaults.standard.set(data, forKey: usersKey)
        } catch {
            print("Failed to save users:", error)
        }
    }
    
    private func loadUsers() {
        guard let data = UserDefaults.standard.data(forKey: usersKey) else {
            print("No saved users found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            users = try decoder.decode([User].self, from: data)
            print("Loaded \(users.count) users")
        } catch {
            print("Failed to load users:", error)
        }
    }
    
    private func saveCurrentUser() {
        if let userId = currentUser?.id {
            UserDefaults.standard.set(userId.uuidString, forKey: currentUserKey)
        } else {
            UserDefaults.standard.removeObject(forKey: currentUserKey)
        }
    }
    
    private func loadCurrentUser() {
        guard let uuidString = UserDefaults.standard.string(forKey: currentUserKey),
              let uuid = UUID(uuidString: uuidString) else {
            print("ℹ️ No current user set")
            return
        }
        
        currentUser = getUser(by: uuid)
        print("Current user:", currentUser?.name ?? "Unknown")
    }
    
    // MARK: - Utility
    
    func clearAllData() {
        users = []
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: usersKey)
        UserDefaults.standard.removeObject(forKey: currentUserKey)
        print("All user data cleared")
    }
}
