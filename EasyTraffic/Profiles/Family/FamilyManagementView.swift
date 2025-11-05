//
//  FamilyManagementView.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 11/5/25.
//

import SwiftUI

struct FamilyManagementView: View {
    @StateObject private var familyManager = FamilyManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showingCreateFamily = false
    @State private var showingInviteMember = false
    
    var currentUser: User? {
        userManager.currentUser
    }
    
    var currentFamily: Family? {
        guard let user = currentUser else { return nil }
        return familyManager.getFamilyForUser(user)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if let family = currentFamily {
                    familyDetailView(family: family)
                } else {
                    noFamilyView
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showingCreateFamily) {
                CreateFamilyView()
            }
            .sheet(isPresented: $showingInviteMember) {
                if let family = currentFamily {
                    InviteMemberView(family: family)
                }
            }
        }
    }
    
    // MARK: - No Family View
    
    private var noFamilyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Family Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a family to share drive data with parents and children")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingCreateFamily = true }) {
                Label("Create Family", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Family Detail View
    
    private func familyDetailView(family: Family) -> some View {
        List {
            // Family Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(family.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Created \(family.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Parents Section
            Section(header: Text("Parents")) {
                ForEach(familyManager.getParentUsers(for: family)) { parent in
                    FamilyMemberRow(user: parent, role: .parent)
                }
            }
            
            // Children Section
            Section(header: Text("Children")) {
                ForEach(familyManager.getChildUsers(for: family)) { child in
                    FamilyMemberRow(user: child, role: .child)
                }
                
                if currentUser?.isParent == true {
                    Button(action: { showingInviteMember = true }) {
                        Label("Invite Child", systemImage: "person.badge.plus")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Actions Section (Parents only)
            if currentUser?.isParent == true {
                Section {
                    Button(action: { showingInviteMember = true }) {
                        Label("Invite Family Member", systemImage: "envelope")
                    }
                    
                    Button(role: .destructive, action: leaveFamily) {
                        Label("Leave Family", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
    
    private func leaveFamily() {
        guard let user = currentUser, let family = currentFamily else { return }
        familyManager.removeMember(user, from: family)
    }
}

// MARK: - Family Member Row

struct FamilyMemberRow: View {
    let user: User
    let role: UserRole
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: role.icon)
                .font(.title3)
                .foregroundColor(role == .parent ? .blue : .green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                
                if let email = user.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(role.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(role == .parent ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                .foregroundColor(role == .parent ? .blue : .green)
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Family View

struct CreateFamilyView: View {
    @StateObject private var familyManager = FamilyManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var familyName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Family Name")) {
                    TextField("e.g., The Smith Family", text: $familyName)
                }
                
                Section {
                    Button(action: createFamily) {
                        Text("Create Family")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(familyName.isEmpty ? .gray : .blue)
                    }
                    .disabled(familyName.isEmpty)
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createFamily() {
        guard let currentUser = userManager.currentUser else { return }
        _ = familyManager.createFamily(name: familyName, createdBy: currentUser)
        dismiss()
    }
}

// MARK: - Invite Member View

struct InviteMemberView: View {
    let family: Family
    
    @StateObject private var familyManager = FamilyManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var selectedRole: UserRole = .child
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invite Details")) {
                    TextField("Email Address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Picker("Role", selection: $selectedRole) {
                        Text("Child").tag(UserRole.child)
                        Text("Parent").tag(UserRole.parent)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Text("An invitation will be sent to this email. They'll be able to accept it when they log in with this email address.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: sendInvite) {
                        Text("Send Invite")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(email.isEmpty ? .gray : .blue)
                    }
                    .disabled(email.isEmpty)
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Invite Sent!", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("An invitation has been sent to \(email)")
            }
        }
    }
    
    private func sendInvite() {
        guard let currentUser = userManager.currentUser else { return }
        
        _ = familyManager.createInvite(
            familyId: family.id,
            email: email,
            role: selectedRole,
            invitedBy: currentUser.id
        )
        
        showingSuccess = true
    }
}

struct FamilyManagementView_Previews: PreviewProvider {
    static var previews: some View {
        FamilyManagementView()
    }
}
