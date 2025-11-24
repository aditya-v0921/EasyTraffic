//
//  UserManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 10/29/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage

class UserManager: ObservableObject {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var users: [User] = []
    @Published var currentUser: User?
    
    private init() {
        listenToUsers()
    }
    
    // 1. Listen for real-time updates from Cloud
    private func listenToUsers() {
        db.collection("users").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching users: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            self.users = documents.compactMap { try? $0.data(as: User.self) }
            
            // Re-sync current user if they exist in the new list
            if let current = self.currentUser {
                self.currentUser = self.users.first { $0.id == current.id }
            }
        }
    }

    // 2. Create User (with Image Upload)
    func createUser(name: String, email: String?, image: UIImage? = nil, completion: @escaping () -> Void = {}) {
        var newUser = User(name: name, email: email)
        
        // Save to Firestore first to get an ID
        do {
            let ref = try db.collection("users").addDocument(from: newUser)
            let userId = ref.documentID
            newUser.id = userId
            
            if let image = image {
                // If we have an image, upload it now
                uploadImage(image, userId: userId) { url in
                    newUser.profileImageUrl = url
                    // Update the user again with the image URL
                    try? self.db.collection("users").document(userId).setData(from: newUser)
                    completion()
                }
            } else {
                completion()
            }
        } catch {
            print("Error creating user: \(error)")
        }
    }
    
    // 3. Update User
    func updateUser(_ user: User, newImage: UIImage? = nil) {
        guard let userId = user.id else { return }
        var userToUpdate = user
        
        if let newImage = newImage {
            uploadImage(newImage, userId: userId) { url in
                userToUpdate.profileImageUrl = url
                try? self.db.collection("users").document(userId).setData(from: userToUpdate)
            }
        } else {
            try? db.collection("users").document(userId).setData(from: userToUpdate)
        }
    }
    
    // Helper: Image Upload
    private func uploadImage(_ image: UIImage, userId: String, completion: @escaping (String) -> Void) {
        let ref = storage.reference().child("profile_images/\(userId).jpg")
        guard let data = image.jpegData(compressionQuality: 0.5) else { return }
        
        ref.putData(data, metadata: nil) { _, error in
            if error == nil {
                ref.downloadURL { url, _ in
                    if let urlString = url?.absoluteString {
                        completion(urlString)
                    }
                }
            }
        }
    }
    
    func setCurrentUser(_ user: User) {
        self.currentUser = user
        var updated = user
        updated.updateLastActive()
        updateUser(updated)
    }
    
    func getUser(by id: String) -> User? {
        return users.first { $0.id == id }
    }
}
