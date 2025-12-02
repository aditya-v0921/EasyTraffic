//
//  FirebaseDriveManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 12/1/25.
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift
import CoreLocation

class FirebaseDriveManager: ObservableObject {
    static let shared = FirebaseDriveManager()
    
    private let db = Firestore.firestore()
    private let drivesCollection = "drives"
    
    @Published var currentDrive: Drive?
    @Published var drives: [Drive] = []
    @Published var isLoading = false
    
    private var driveListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Start Drive
    
    func startDrive(for user: User) async {
        guard currentDrive == nil else {
            print("Drive already in progress")
            return
        }
        
        let family = FirebaseFamilyManager.shared.families.first { $0.id == user.familyId }
        var newDrive = Drive(userId: user.id, familyId: family?.id)
        
        do {
            // Save to Firebase
            let docRef = db.collection(drivesCollection).document(newDrive.id.uuidString)
            try docRef.setData(from: newDrive)
            
            DispatchQueue.main.async {
                self.currentDrive = newDrive
                print("Drive started:", newDrive.id)
            }
        } catch {
            print("Failed to start drive:", error)
            // Still set current drive locally for offline support
            DispatchQueue.main.async {
                self.currentDrive = newDrive
            }
        }
    }
    
    // MARK: - End Drive
    
    func endDrive() async {
        guard var drive = currentDrive else {
            print("No active drive to end")
            return
        }
        
        drive.endTime = Date()
        drive.isActive = false
        
        do {
            // Save final state to Firebase
            let docRef = db.collection(drivesCollection).document(drive.id.uuidString)
            try docRef.setData(from: drive)
            
            DispatchQueue.main.async {
                self.drives.insert(drive, at: 0)
                self.currentDrive = nil
                print("Drive ended:", drive.id)
            }
        } catch {
            print("Failed to end drive:", error)
            // Still save locally
            DispatchQueue.main.async {
                self.drives.insert(drive, at: 0)
                self.currentDrive = nil
            }
        }
    }
    
    // MARK: - Add Event to Current Drive
    
    func addStopSignEvent(didStop: Bool, stopDuration: TimeInterval?, confidence: Float, location: CLLocationCoordinate2D? = nil) async {
        guard var drive = currentDrive else {
            print("No active drive")
            return
        }
        
        let event = StopSignEvent(
            timestamp: Date(),
            didFullStop: didStop,
            stopDuration: stopDuration,
            confidence: confidence,
            location: location
        )
        
        // Add to local drive
        drive.events.append(event)
        
        // Save to Firebase
        do {
            let docRef = db.collection(drivesCollection).document(drive.id.uuidString)
            try docRef.setData(from: drive)
            
            DispatchQueue.main.async {
                self.currentDrive = drive
            }
            
            print("Event saved to Firebase")
        } catch {
            print("Failed to save event to Firebase:", error)
            DispatchQueue.main.async {
                self.currentDrive = drive
            }
        }
    }
    
    // MARK: - Fetch Drives
    
    func fetchDrives(for user: User) async {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            let query = db.collection(drivesCollection)
                .whereField("userId", isEqualTo: user.id.uuidString)
                .order(by: "startTime", descending: true)
            
            let snapshot = try await query.getDocuments()
            
            let fetchedDrives = snapshot.documents.compactMap { document -> Drive? in
                try? document.data(as: Drive.self)
            }
            
            DispatchQueue.main.async {
                self.drives = fetchedDrives
                self.isLoading = false
                print("Fetched \(fetchedDrives.count) drives from Firebase")
            }
        } catch {
            print("Failed to fetch drives:", error)
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Fetch Family Drives (Parents viewing children)
    
    func fetchFamilyDrives(for family: Family) async -> [UUID: [Drive]] {
        var drivesByUser: [UUID: [Drive]] = [:]
        
        do {
            let query = db.collection(drivesCollection)
                .whereField("familyId", isEqualTo: family.id.uuidString)
                .order(by: "startTime", descending: true)
            
            let snapshot = try await query.getDocuments()
            
            let familyDrives = snapshot.documents.compactMap { document -> Drive? in
                try? document.data(as: Drive.self)
            }
            
            // Group by user
            for drive in familyDrives {
                if drivesByUser[drive.userId] == nil {
                    drivesByUser[drive.userId] = []
                }
                drivesByUser[drive.userId]?.append(drive)
            }
            
            print("Fetched family drives for \(drivesByUser.keys.count) users")
        } catch {
            print("Failed to fetch family drives:", error)
        }
        
        return drivesByUser
    }
    
    // MARK: - Delete Drive
    
    func deleteDrive(_ drive: Drive) async {
        do {
            let docRef = db.collection(drivesCollection).document(drive.id.uuidString)
            try await docRef.delete()
            
            DispatchQueue.main.async {
                self.drives.removeAll { $0.id == drive.id }
                print("Drive deleted")
            }
        } catch {
            print("Failed to delete drive:", error)
        }
    }
    
    // MARK: - Real-time Listener
    
    func listenToDrives(for userId: UUID) {
        driveListener?.remove()
        
        let query = db.collection(drivesCollection)
            .whereField("userId", isEqualTo: userId.uuidString)
            .order(by: "startTime", descending: true)
        
        driveListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Drives listener error:", error)
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            let drives = snapshot.documents.compactMap { document -> Drive? in
                try? document.data(as: Drive.self)
            }
            
            DispatchQueue.main.async {
                self.drives = drives
                print("Drives updated in real-time: \(drives.count)")
            }
        }
    }
    
    func stopListening() {
        driveListener?.remove()
    }
    
    // MARK: - Statistics
    
    func getStatistics(for drives: [Drive]) -> DriveStatistics {
        let totalDrives = drives.count
        let totalStops = drives.reduce(0) { $0 + $1.events.count }
        let totalFullStops = drives.reduce(0) { $0 + $1.events.filter { $0.didFullStop }.count }
        let totalRollingStops = totalStops - totalFullStops
        let avgScore = drives.isEmpty ? 0 : drives.reduce(0) { $0 + $1.summary.score } / totalDrives
        
        return DriveStatistics(
            totalDrives: totalDrives,
            totalStopSigns: totalStops,
            fullStops: totalFullStops,
            rollingStops: totalRollingStops,
            averageScore: avgScore
        )
    }
}

// MARK: - Drive Statistics

struct DriveStatistics {
    let totalDrives: Int
    let totalStopSigns: Int
    let fullStops: Int
    let rollingStops: Int
    let averageScore: Int
    
    var fullStopPercentage: Double {
        guard totalStopSigns > 0 else { return 0 }
        return Double(fullStops) / Double(totalStopSigns) * 100
    }
}
