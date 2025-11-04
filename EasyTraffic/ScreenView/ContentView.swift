import SwiftUI

struct ContentView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var showingProfileSelection = false
    @State private var showingCamera = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current User Display
                if let currentUser = userManager.currentUser {
                    currentUserCard(user: currentUser)
                } else {
                    noUserSelectedView
                }
                
                Spacer()
                
                // App Info
                appInfoSection
                
                Spacer()
                
                // Action Buttons
                actionButtons
            }
            .padding()
            .navigationTitle("EasyTraffic")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingProfileSelection = true }) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingProfileSelection) {
                ProfileSelectionView { selectedUser in
                    print("✅ Selected user: \(selectedUser.name)")
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView()
            }
        }
    }
    
    // MARK: - Current User Card
    
    private func currentUserCard(user: User) -> some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                
                Text(user.name.prefix(1).uppercased())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let email = user.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Active profile")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button(action: { showingProfileSelection = true }) {
                Text("Switch")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - No User Selected
    
    private var noUserSelectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("No Profile Selected")
                .font(.headline)
            
            Button(action: { showingProfileSelection = true }) {
                Text("Select Profile")
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Ready to Drive")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("The app will detect stop signs and track your driving behavior")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: startDrive) {
                Label("Start Drive", systemImage: "play.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userManager.currentUser == nil ? Color.gray : Color.green)
                    .cornerRadius(12)
            }
            .disabled(userManager.currentUser == nil)
            
            Button(action: viewDriveHistory) {
                Label("Drive History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            .disabled(userManager.currentUser == nil)
        }
    }
    
    // MARK: - Actions
    
    private func startDrive() {
        guard let user = userManager.currentUser else { return }
        print("🚗 Starting drive for user: \(user.name)")
        
        // Show camera view
        showingCamera = true
    }
    
    private func viewDriveHistory() {
        guard let user = userManager.currentUser else { return }
        print("📊 Viewing drive history for user: \(user.name)")
        // TODO: Implement drive history view in Phase 2
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
