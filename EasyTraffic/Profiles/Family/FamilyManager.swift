//
//  FamilyManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 11/5/25.
//

import Foundation

class FamilyManager: ObservableObject {
    static let shared = FamilyManager()
    
    @Published var families: [Family] = []
    @Published var invites: [FamilyInvite] = []
    
    private let familiesKey = "saved_families"
    private let invitesKey = "saved_invites"
    
    private init() {
        loadFamilies()
        loadInvites()
    }
    
    // MARK: - Family Management
    
    func createFamily(name: String, createdBy: User) -> Family {
        let family = Family(name: name, createdBy: createdBy.id, parentIds: [createdBy.id])
        families.append(family)
        saveFamilies()
        
        // Update user's familyId
        var updatedUser = createdBy
        updatedUser.familyId = family.id
        UserManager.shared.updateUser(updatedUser)
        
        return family
    }
    
    func updateFamily(_ family: Family) {
        if let index = families.firstIndex(where: { $0.id == family.id }) {
            families[index] = family
            saveFamilies()
        }
    }
    
    func deleteFamily(_ family: Family) {
        // Remove family reference from all members
        let allMemberIds = family.parentIds + family.childIds
        for userId in allMemberIds {
            if var user = UserManager.shared.getUser(by: userId) {
                user.familyId = nil
                UserManager.shared.updateUser(user)
            }
        }
        
        // Remove all invites for this family
        invites.removeAll { $0.familyId == family.id }
        saveInvites()
        
        // Remove family
        families.removeAll { $0.id == family.id }
        saveFamilies()
    }
    
    func getFamily(by id: UUID) -> Family? {
        return families.first { $0.id == id }
    }
    
    func getFamilyForUser(_ user: User) -> Family? {
        guard let familyId = user.familyId else { return nil }
        return getFamily(by: familyId)
    }
    
    // MARK: - Family Members
    
    func addParent(_ user: User, to family: Family) {
        guard var updatedFamily = getFamily(by: family.id) else { return }
        
        if !updatedFamily.parentIds.contains(user.id) {
            updatedFamily.parentIds.append(user.id)
            updateFamily(updatedFamily)
            
            var updatedUser = user
            updatedUser.familyId = family.id
            updatedUser.role = .parent
            UserManager.shared.updateUser(updatedUser)
        }
    }
    
    func addChild(_ user: User, to family: Family) {
        guard var updatedFamily = getFamily(by: family.id) else { return }
        
        if !updatedFamily.childIds.contains(user.id) {
            updatedFamily.childIds.append(user.id)
            updateFamily(updatedFamily)
            
            var updatedUser = user
            updatedUser.familyId = family.id
            updatedUser.role = .child
            UserManager.shared.updateUser(updatedUser)
        }
    }
    
    func removeMember(_ user: User, from family: Family) {
        guard var updatedFamily = getFamily(by: family.id) else { return }
        
        updatedFamily.parentIds.removeAll { $0 == user.id }
        updatedFamily.childIds.removeAll { $0 == user.id }
        updateFamily(updatedFamily)
        
        var updatedUser = user
        updatedUser.familyId = nil
        UserManager.shared.updateUser(updatedUser)
    }
    
    func getParentUsers(for family: Family) -> [User] {
        return family.parentIds.compactMap { UserManager.shared.getUser(by: $0) }
    }
    
    func getChildUsers(for family: Family) -> [User] {
        return family.childIds.compactMap { UserManager.shared.getUser(by: $0) }
    }
    
    func getAllMembers(for family: Family) -> [User] {
        return getParentUsers(for: family) + getChildUsers(for: family)
    }
    
    // MARK: - Invites
    
    func createInvite(familyId: UUID, email: String, role: UserRole, invitedBy: UUID) -> FamilyInvite {
        let invite = FamilyInvite(familyId: familyId, invitedEmail: email, role: role, invitedBy: invitedBy)
        invites.append(invite)
        saveInvites()
        return invite
    }
    
    func getInvitesForUser(email: String) -> [FamilyInvite] {
        return invites.filter {
            $0.invitedEmail.lowercased() == email.lowercased() &&
            $0.status == .pending &&
            !$0.isExpired()
        }
    }
    
    func acceptInvite(_ invite: FamilyInvite, by user: User) -> Bool {
        guard let family = getFamily(by: invite.familyId) else { return false }
        
        // Update invite status
        if let index = invites.firstIndex(where: { $0.id == invite.id }) {
            invites[index].status = .accepted
            saveInvites()
        }
        
        // Add user to family
        if invite.role == .parent {
            addParent(user, to: family)
        } else {
            addChild(user, to: family)
        }
        
        return true
    }
    
    func declineInvite(_ invite: FamilyInvite) {
        if let index = invites.firstIndex(where: { $0.id == invite.id }) {
            invites[index].status = .declined
            saveInvites()
        }
    }
    
    // MARK: - Permissions
    
    func canAccessDriveData(viewer: User, target: User) -> Bool {
        // Can always view own data
        if viewer.id == target.id {
            return true
        }
        
        // Parents can view their children's data
        if viewer.isParent, target.isChild {
            if let viewerFamily = getFamilyForUser(viewer),
               let targetFamily = getFamilyForUser(target),
               viewerFamily.id == targetFamily.id {
                return true
            }
        }
        
        return false
    }
    
    func getAccessibleUsers(for user: User) -> [User] {
        var accessible: [User] = [user] // Always include self
        
        if user.isParent, let family = getFamilyForUser(user) {
            // Parents can access all children in their family
            accessible.append(contentsOf: getChildUsers(for: family))
        }
        
        return accessible
    }
    
    // MARK: - Persistence
    
    private func saveFamilies() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(families)
            UserDefaults.standard.set(data, forKey: familiesKey)
        } catch {
            print("❌ Failed to save families:", error)
        }
    }
    
    private func loadFamilies() {
        guard let data = UserDefaults.standard.data(forKey: familiesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            families = try decoder.decode([Family].self, from: data)
            print("Loaded \(families.count) families")
        } catch {
            print("Failed to load families:", error)
        }
    }
    
    private func saveInvites() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(invites)
            UserDefaults.standard.set(data, forKey: invitesKey)
        } catch {
            print("Failed to save invites:", error)
        }
    }
    
    private func loadInvites() {
        guard let data = UserDefaults.standard.data(forKey: invitesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            invites = try decoder.decode([FamilyInvite].self, from: data)
            print("Loaded \(invites.count) invites")
        } catch {
            print("Failed to load invites:", error)
        }
    }
    
    func clearAllData() {
        families = []
        invites = []
        UserDefaults.standard.removeObject(forKey: familiesKey)
        UserDefaults.standard.removeObject(forKey: invitesKey)
        print("All family data cleared")
    }
}
