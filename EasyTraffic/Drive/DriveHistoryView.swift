import SwiftUI

struct DriveHistoryView: View {
    @StateObject private var driveManager = FirebaseDriveManager.shared
    @StateObject private var userManager = FirebaseUserManager.shared
    @StateObject private var familyManager = FirebaseFamilyManager.shared
    
    @State private var selectedDrive: Drive?
    @State private var isLoadingFamily = false
    @State private var familyDrives: [UUID: [Drive]] = [:]
    
    var currentUser: User? {
        userManager.currentUser
    }
    
    var isParent: Bool {
        currentUser?.isParent ?? false
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if driveManager.isLoading || isLoadingFamily {
                    ProgressView("Loading drives...")
                } else if isParent && !familyDrives.isEmpty {
                    familyDrivesView
                } else if driveManager.drives.isEmpty {
                    emptyStateView
                } else {
                    driveListView
                }
            }
            .navigationTitle("Drive History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshDrives) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(driveManager.isLoading)
                }
            }
            .sheet(item: $selectedDrive) { drive in
                DriveDetailView(drive: drive)
            }
            .task {
                await loadDrives()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Drives Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a drive to begin tracking your performance")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Drive List (Personal)
    
    private var driveListView: some View {
        List {
            Section(header: statisticsHeader) {
                ForEach(driveManager.drives) { drive in
                    DriveRow(drive: drive)
                        .onTapGesture {
                            selectedDrive = drive
                        }
                }
            }
        }
    }
    
    private var statisticsHeader: some View {
        let stats = driveManager.getStatistics(for: driveManager.drives)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                StatBadge(title: "Total Drives", value: "\(stats.totalDrives)")
                StatBadge(title: "Avg Score", value: "\(stats.averageScore)")
                StatBadge(title: "Full Stops", value: "\(stats.fullStops)")
            }
            
            HStack {
                Text("Full Stop Rate:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(stats.fullStopPercentage))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(stats.fullStopPercentage >= 80 ? .green : .orange)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Family Drives View (Parents)
        
        private var familyDrivesView: some View {
            List {
                ForEach(Array(familyDrives.keys), id: \.self) { userId in
                    // Convert the UUID to a String
                    if let user = userManager.getUser(by: userId.uuidString),
                       let drives = familyDrives[userId] {
                        Section(header: familyMemberHeader(user: user, drives: drives)) {
                            ForEach(drives) { drive in
                                DriveRow(drive: drive)
                                    .onTapGesture {
                                        selectedDrive = drive
                                    }
                            }
                        }
                    }
                }
            }
        }
    
    private func familyMemberHeader(user: User, drives: [Drive]) -> some View {
        let stats = driveManager.getStatistics(for: drives)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: user.role.icon)
                    .foregroundColor(user.role == .parent ? .blue : .green)
                Text(user.name)
                    .font(.headline)
            }
            
            HStack(spacing: 15) {
                StatBadge(title: "Drives", value: "\(stats.totalDrives)", size: .small)
                StatBadge(title: "Score", value: "\(stats.averageScore)", size: .small)
                StatBadge(title: "Full Stops", value: "\(Int(stats.fullStopPercentage))%", size: .small)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func loadDrives() async {
        guard let user = currentUser else { return }
        
        // Load personal drives
        await driveManager.fetchDrives(for: user)
        
        // If parent, also load family drives
        if isParent, let familyId = user.familyId {
            if let family = try? await familyManager.fetchFamily(by: familyId) {
                isLoadingFamily = true
                let drives = await driveManager.fetchFamilyDrives(for: family)
                DispatchQueue.main.async {
                    self.familyDrives = drives
                    self.isLoadingFamily = false
                }
            }
        }
    }
    
    private func refreshDrives() {
        Task {
            await loadDrives()
        }
    }
}

// MARK: - Drive Row

struct DriveRow: View {
    let drive: Drive
    
    var body: some View {
        HStack(spacing: 12) {
            // Grade Badge
            ZStack {
                Circle()
                    .fill(gradeColor)
                    .frame(width: 50, height: 50)
                
                Text(drive.summary.grade)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Drive Info
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.startTime, style: .date)
                    .font(.headline)
                
                Text(drive.startTime, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label("\(drive.events.count)", systemImage: "octagon.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    if let duration = drive.duration {
                        Label(formatDuration(duration), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(drive.summary.score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(gradeColor)
                
                Text("score")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var gradeColor: Color {
        switch drive.summary.grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        default: return .red
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let title: String
    let value: String
    var size: Size = .normal
    
    enum Size {
        case normal, small
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(size == .normal ? .title3 : .subheadline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, size == .normal ? 12 : 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Drive Detail View

struct DriveDetailView: View {
    let drive: Drive
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Summary Section
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Grade")
                        Spacer()
                        Text(drive.summary.grade)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(gradeColor)
                    }
                    
                    HStack {
                        Text("Score")
                        Spacer()
                        Text("\(drive.summary.score)/100")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        if let duration = drive.duration {
                            Text(formatDuration(duration))
                        }
                    }
                    
                    HStack {
                        Text("Start Time")
                        Spacer()
                        Text(drive.startTime, style: .time)
                            .foregroundColor(.secondary)
                    }
                    
                    if let endTime = drive.endTime {
                        HStack {
                            Text("End Time")
                            Spacer()
                            Text(endTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Stop Signs Section
                Section(header: Text("Stop Signs (\(drive.events.count))")) {
                    HStack {
                        Text("Full Stops")
                        Spacer()
                        Text("\(drive.summary.fullStops)")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Rolling Stops")
                        Spacer()
                        Text("\(drive.summary.rollingStops)")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                    
                    if drive.summary.averageStopDuration > 0 {
                        HStack {
                            Text("Avg Stop Duration")
                            Spacer()
                            Text(String(format: "%.1fs", drive.summary.averageStopDuration))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Event Timeline
                if !drive.events.isEmpty {
                    Section(header: Text("Timeline")) {
                        ForEach(drive.events) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
            .navigationTitle("Drive Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var gradeColor: Color {
        switch drive.summary.grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        default: return .red
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: StopSignEvent
    
    var body: some View {
        HStack {
            Image(systemName: event.didFullStop ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(event.didFullStop ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.timestamp, style: .time)
                    .font(.subheadline)
                
                if let duration = event.stopDuration {
                    Text("Stopped for \(String(format: "%.1f", duration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(event.didFullStop ? "Full Stop" : "Rolling")
                .font(.caption)
                .foregroundColor(event.didFullStop ? .green : .red)
        }
    }
}

struct DriveHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        DriveHistoryView()
    }
}
