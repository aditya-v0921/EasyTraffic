//
//  FirebaseFamilyManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 11/23/25.
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

class FirebaseFamilyManager: ObservableObject {
    static let shared = FirebaseFamilyManager()
    
    private let db = Firestore.firestore()
    private let familiesCollection = "families"
    private let invitesCollection = "family_invites"
    
    @Published var families: [Family] = []
    @Published var invites: [FamilyInvite] = []
    
    private var familyListener: ListenerRegistration?
    private var inviteListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Create Family
    
    func createFamily(name: String, createdBy: User) async throws -> Family {
        let family = Family(name: name, createdBy: createdBy.id, parentIds: [createdBy.id])
        
        let docRef = db.collection(familiesCollection).document(family.id.uuidString)
        
        do {
            try docRef.setData(from: family)
            print("Family created:", family.id)
            
            // Update user's familyId
            var updatedUser = createdBy
            updatedUser.familyId = family.id
            try await FirebaseUserManager.shared.updateUser(updatedUser)
            
            DispatchQueue.main.async {
                self.families.append(family)
            }
            
            return family
        } catch {
            print("Failed to create family:", error)
            throw error
        }
    }
    
    // MARK: - Update Family
    
    func updateFamily(_ family: Family) async throws {
        let docRef = db.collection(familiesCollection).document(family.id.uuidString)
        
        do {
            try docRef.setData(from: family)
            print("Family updated:", family.id)
            
            DispatchQueue.main.async {
                if let index = self.families.firstIndex(where: { $0.id == family.id }) {
                    self.families[index] = family
                }
            }
        } catch {
            print("Failed to update family:", error)
            throw error
        }
    }
    
    // MARK: - Fetch Family
    
    func fetchFamily(by id: UUID) async throws -> Family? {
        let docRef = db.collection(familiesCollection).document(id.uuidString)
        
        do {
            let family = try await docRef.getDocument(as: Family.self)
            print("Family fetched:", family.id)
            return family
        } catch {
            print("Failed to fetch family:", error)
            return nil
        }
    }
    
    // MARK: - Delete Family
    
    func deleteFamily(_ family: Family) async throws {
        let docRef = db.collection(familiesCollection).document(family.id.uuidString)
        
        // Remove family reference from all members
        let allMemberIds = family.parentIds + family.childIds
        for userId in allMemberIds {
            if var user = try await FirebaseUserManager.shared.fetchUser(by: userId) {
                user.familyId = nil
                try await FirebaseUserManager.shared.updateUser(user)
            }
        }
        
        // Delete all invites for this family
        let invitesQuery = db.collection(invitesCollection).whereField("familyId", isEqualTo: family.id.uuidString)
        let invitesSnapshot = try await invitesQuery.getDocuments()
        
        for document in invitesSnapshot.documents {
            try await document.reference.delete()
        }
        
        // Delete family
        try await docRef.delete()
        print("Family deleted")
        
        DispatchQueue.main.async {
            self.families.removeAll { $0.id == family.id }
        }
    }
    
    // MARK: - Add Member
    
    func addMember(_ user: User, to family: Family, as role: UserRole) async throws {
        var updatedFamily = family
        
        if role == .parent && !updatedFamily.parentIds.contains(user.id) {
            updatedFamily.parentIds.append(user.id)
        } else if role == .child && !updatedFamily.childIds.contains(user.id) {
            updatedFamily.childIds.append(user.id)
        }
        
        try await updateFamily(updatedFamily)
        
        // Update user's family and role
        var updatedUser = user
        updatedUser.familyId = family.id
        updatedUser.role = role
        try await FirebaseUserManager.shared.updateUser(updatedUser)
        
        print("Member added to family")
    }
    
    // MARK: - Remove Member
    
    func removeMember(_ user: User, from family: Family) async throws {
        var updatedFamily = family
        
        updatedFamily.parentIds.removeAll { $0 == user.id }
        updatedFamily.childIds.removeAll { $0 == user.id }
        
        try await updateFamily(updatedFamily)
        
        // Update user
        var updatedUser = user
        updatedUser.familyId = nil
        try await FirebaseUserManager.shared.updateUser(updatedUser)
        
        print("Member removed from family")
    }
    
    // MARK: - Invites
    
    func createInvite(familyId: UUID, email: String, role: UserRole, invitedBy: UUID) async throws -> FamilyInvite {
        let invite = FamilyInvite(familyId: familyId, invitedEmail: email, role: role, invitedBy: invitedBy)
        
        let docRef = db.collection(invitesCollection).document(invite.id.uuidString)
        
        do {
            try docRef.setData(from: invite)
            print("Invite created:", invite.id)
            
            DispatchQueue.main.async {
                self.invites.append(invite)
            }
            
            return invite
        } catch {
            print("Failed to create invite:", error)
            throw error
        }
    }
    
    func fetchInvites(for email: String) async throws -> [FamilyInvite] {
        let query = db.collection(invitesCollection)
            .whereField("invitedEmail", isEqualTo: email)
            .whereField("status", isEqualTo: "pending")
        
        do {
            let snapshot = try await query.getDocuments()
            
            let invites = snapshot.documents.compactMap { document -> FamilyInvite? in
                try? document.data(as: FamilyInvite.self)
            }.filter { !$0.isExpired() }
            
            DispatchQueue.main.async {
                self.invites = invites
            }
            
            print("Fetched \(invites.count) invites for \(email)")
            return invites
        } catch {
            print("Failed to fetch invites:", error)
            throw error
        }
    }
    
    func acceptInvite(_ invite: FamilyInvite, by user: User) async throws {
        guard let family = try await fetchFamily(by: invite.familyId) else {
            throw NSError(domain: "FirebaseFamilyManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Family not found"])
        }
        
        // Update invite status
        var updatedInvite = invite
        updatedInvite.status = .accepted
        
        let docRef = db.collection(invitesCollection).document(invite.id.uuidString)
        try docRef.setData(from: updatedInvite)
        
        // Add user to family
        try await addMember(user, to: family, as: invite.role)
        
        print("Invite accepted")
    }
    
    func declineInvite(_ invite: FamilyInvite) async throws {
        var updatedInvite = invite
        updatedInvite.status = .declined
        
        let docRef = db.collection(invitesCollection).document(invite.id.uuidString)
        try docRef.setData(from: updatedInvite)
        
        DispatchQueue.main.async {
            self.invites.removeAll { $0.id == invite.id }
        }
        
        print("Invite declined")
    }
    
    // MARK: - Real-time Listeners
    
    func listenToFamilyChanges(familyId: UUID) {
        familyListener?.remove()
        
        let docRef = db.collection(familiesCollection).document(familyId.uuidString)
        
        familyListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Family listener error:", error)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else { return }
            
            do {
                let family = try snapshot.data(as: Family.self)
                DispatchQueue.main.async {
                    if let index = self.families.firstIndex(where: { $0.id == family.id }) {
                        self.families[index] = family
                    } else {
                        self.families.append(family)
                    }
                    print("Family updated in real-time")
                }
            } catch {
                print("Failed to decode family:", error)
            }
        }
    }
    
    func listenToInvites(for email: String) {
        inviteListener?.remove()
        
        let query = db.collection(invitesCollection)
            .whereField("invitedEmail", isEqualTo: email)
            .whereField("status", isEqualTo: "pending")
        
        inviteListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Invites listener error:", error)
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            let invites = snapshot.documents.compactMap { document -> FamilyInvite? in
                try? document.data(as: FamilyInvite.self)
            }.filter { !$0.isExpired() }
            
            DispatchQueue.main.async {
                self.invites = invites
                print("Invites updated in real-time: \(invites.count)")
            }
        }
    }
    
    func stopListening() {
        familyListener?.remove()
        inviteListener?.remove()
    }
}
