//
//  PendingInvitesView.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 11/5/25.
//

import SwiftUI

struct PendingInvitesView: View {
    @StateObject private var familyManager = FamilyManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    var currentUser: User? {
        userManager.currentUser
    }
    
    var pendingInvites: [FamilyInvite] {
        guard let email = currentUser?.email else { return [] }
        return familyManager.getInvitesForUser(email: email)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if pendingInvites.isEmpty {
                    emptyStateView
                } else {
                    invitesList
                }
            }
            .navigationTitle("Family Invites")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.open")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Pending Invites")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("You'll see family invitations here when someone adds you to their family")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var invitesList: some View {
        List {
            ForEach(pendingInvites) { invite in
                InviteRow(invite: invite, currentUser: currentUser)
            }
        }
    }
}

struct InviteRow: View {
    let invite: FamilyInvite
    let currentUser: User?
    
    @StateObject private var familyManager = FamilyManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showingAcceptConfirmation = false
    @State private var showingDeclineConfirmation = false
    
    var family: Family? {
        familyManager.getFamily(by: invite.familyId)
    }
    
    var inviter: User? {
        userManager.getUser(by: invite.invitedBy)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let familyName = family?.name {
                        Text(familyName)
                            .font(.headline)
                    }
                    
                    if let inviterName = inviter?.name {
                        Text("Invited by \(inviterName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: invite.role.icon)
                            .font(.caption)
                        Text("Join as \(invite.role.displayName)")
                            .font(.caption)
                    }
                    .foregroundColor(invite.role == .parent ? .blue : .green)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: { showingAcceptConfirmation = true }) {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                
                Button(action: { showingDeclineConfirmation = true }) {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
        .alert("Accept Invite?", isPresented: $showingAcceptConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Accept") { acceptInvite() }
        } message: {
            if let familyName = family?.name {
                Text("Join \(familyName) as a \(invite.role.displayName)?")
            }
        }
        .alert("Decline Invite?", isPresented: $showingDeclineConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Decline", role: .destructive) { declineInvite() }
        } message: {
            Text("Are you sure you want to decline this family invitation?")
        }
    }
    
    private func acceptInvite() {
        guard let user = currentUser else { return }
        _ = familyManager.acceptInvite(invite, by: user)
    }
    
    private func declineInvite() {
        familyManager.declineInvite(invite)
    }
}

struct PendingInvitesView_Previews: PreviewProvider {
    static var previews: some View {
        PendingInvitesView()
    }
}
