//
//  ProfileSelectionView.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 10/29/25.
//

import SwiftUI

struct ProfileSelectionView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var showingAddUser = false
    @State private var showingEditUser: User?
    @Environment(\.dismiss) var dismiss
    
    var onProfileSelected: ((User) -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                if userManager.users.isEmpty {
                    emptyStateView
                } else {
                    userListView
                }
            }
            .navigationTitle("Select Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddUser = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddUser) {
                AddEditUserView(mode: .add)
            }
            .sheet(item: $showingEditUser) { user in
                AddEditUserView(mode: .edit(user))
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Profiles Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first profile to start tracking drives")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingAddUser = true }) {
                Label("Create Profile", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - User List
    
    private var userListView: some View {
        List {
            ForEach(userManager.users) { user in
                ProfileRow(
                    user: user,
                    isSelected: userManager.currentUser?.id == user.id,
                    onSelect: {
                        selectUser(user)
                    },
                    onEdit: {
                        showingEditUser = user
                    },
                    onDelete: {
                        deleteUser(user)
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Actions
    
    private func selectUser(_ user: User) {
        userManager.setCurrentUser(user)
        onProfileSelected?(user)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func deleteUser(_ user: User) {
        userManager.deleteUser(user)
    }
    
    private func deleteUsers(at offsets: IndexSet) {
        for index in offsets {
            let user = userManager.users[index]
            userManager.deleteUser(user)
        }
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let user: User
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 15) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    Text(user.name.prefix(1).uppercased())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Last active: \(user.lastActive, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selected Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .alert("Delete Profile?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(user.name)'s profile? This action cannot be undone.")
        }
    }
}

// MARK: - Add/Edit User View

struct AddEditUserView: View {
    enum Mode {
        case add
        case edit(User)
    }
    
    let mode: Mode
    
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    var title: String {
        isEditMode ? "Edit Profile" : "Create Profile"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                if !isEditMode {
                    Section {
                        Text("A valid email address is required to create a profile")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: save) {
                        Text(isEditMode ? "Save Changes" : "Create Profile")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(canSave ? .blue : .gray)
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if case .edit(let user) = mode {
                    name = user.name
                    email = user.email ?? ""
                }
            }
        }
    }
    
    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        // For edit mode, just need a name
        if isEditMode {
            return !trimmedName.isEmpty
        }
        
        // For add mode, need both name and valid email
        return !trimmedName.isEmpty && isValidEmail(trimmedEmail)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            showingError = true
            return
        }
        
        // Validate email for new profiles
        if !isEditMode {
            guard isValidEmail(trimmedEmail) else {
                errorMessage = "Please enter a valid email address"
                showingError = true
                return
            }
        }
        
        let finalEmail = trimmedEmail.isEmpty ? nil : trimmedEmail
        
        // Check for duplicate email (only if email is provided)
        if let finalEmail = finalEmail {
            let isDuplicate = userManager.users.contains { user in
                // Skip self when editing
                if case .edit(let editingUser) = mode, user.id == editingUser.id {
                    return false
                }
                return user.email?.lowercased() == finalEmail.lowercased()
            }
            
            if isDuplicate {
                errorMessage = "An account with this email already exists"
                showingError = true
                return
            }
        }
        
        switch mode {
        case .add:
            _ = userManager.createUser(name: trimmedName, email: finalEmail)
            
        case .edit(let user):
            var updatedUser = user
            updatedUser.name = trimmedName
            updatedUser.email = finalEmail
            userManager.updateUser(updatedUser)
        }
        
        dismiss()
    }
}

// MARK: - Preview

struct ProfileSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSelectionView()
    }
}
