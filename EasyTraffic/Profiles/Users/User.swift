//
//  User.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 10/29/25.
//

import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var email: String?
    let createdAt: Date
    var lastActive: Date
    var role: UserRole
    var familyId: UUID? // Which family this user belongs to
    
    init(id: UUID = UUID(), name: String, email: String? = nil, role: UserRole = .parent, familyId: UUID? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = Date()
        self.lastActive = Date()
        self.role = role
        self.familyId = familyId
    }
    
    // Update last active timestamp
    mutating func updateLastActive() {
        self.lastActive = Date()
    }
    
    var isParent: Bool {
        return role == .parent
    }
    
    var isChild: Bool {
        return role == .child
    }
    
    // For Equatable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
