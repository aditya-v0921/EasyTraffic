//
//  Family.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 11/5/25.
//

import Foundation
//import FirebaseFirestoreSwift
import FirebaseFirestore

// MARK: - User Role

enum UserRole: String, Codable {
    case parent
    case child
    
    var displayName: String {
        switch self {
        case .parent: return "Parent"
        case .child: return "Child"
        }
    }
    
    var icon: String {
        switch self {
        case .parent: return "person.fill"
        case .child: return "figure.child"
        }
    }
}

// MARK: - Family

struct Family: Codable, Identifiable {
    @DocumentID var documentId: String?
    let id: UUID
    var name: String
    var createdBy: UUID // Parent user ID
    var parentIds: [UUID] // Multiple parents allowed
    var childIds: [UUID] // Multiple children
    let createdAt: Date
    
    init(id: UUID = UUID(), name: String, createdBy: UUID, parentIds: [UUID] = [], childIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.parentIds = parentIds.contains(createdBy) ? parentIds : [createdBy] + parentIds
        self.childIds = childIds
        self.createdAt = Date()
    }
    
    func isParent(_ userId: UUID) -> Bool {
        return parentIds.contains(userId)
    }
    
    func isChild(_ userId: UUID) -> Bool {
        return childIds.contains(userId)
    }
    
    func isMember(_ userId: UUID) -> Bool {
        return isParent(userId) || isChild(userId)
    }
    
    enum CodingKeys: String, CodingKey {
        case documentId
        case id
        case name
        case createdBy
        case parentIds
        case childIds
        case createdAt
    }
}

// MARK: - Family Invite

struct FamilyInvite: Codable, Identifiable {
    @DocumentID var documentId: String?
    let id: UUID
    let familyId: UUID
    let invitedEmail: String
    let role: UserRole
    let invitedBy: UUID // Parent user ID
    let createdAt: Date
    var status: InviteStatus
    
    enum InviteStatus: String, Codable {
        case pending
        case accepted
        case declined
        case expired
    }
    
    init(id: UUID = UUID(), familyId: UUID, invitedEmail: String, role: UserRole, invitedBy: UUID) {
        self.id = id
        self.familyId = familyId
        self.invitedEmail = invitedEmail
        self.role = role
        self.invitedBy = invitedBy
        self.createdAt = Date()
        self.status = .pending
    }
    
    func isExpired() -> Bool {
        // Invites expire after 7 days
        let expirationDate = createdAt.addingTimeInterval(7 * 24 * 60 * 60)
        return Date() > expirationDate
    }
    
    enum CodingKeys: String, CodingKey {
        case documentId
        case id
        case familyId
        case invitedEmail
        case role
        case invitedBy
        case createdAt
        case status
    }
}
