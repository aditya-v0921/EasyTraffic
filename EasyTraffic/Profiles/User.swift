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
    
    init(id: UUID = UUID(), name: String, email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = Date()
        self.lastActive = Date()
    }
    
    // Update last active timestamp
    mutating func updateLastActive() {
        self.lastActive = Date()
    }
    
    // For Equatable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
