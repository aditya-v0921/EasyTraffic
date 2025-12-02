//
//  Drive.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 12/1/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore
//import FirebaseFirestoreSwift

// MARK: - Drive Session

struct Drive: Identifiable, Codable {
    @DocumentID var documentId: String?
    var id: UUID
    let userId: UUID
    let familyId: UUID?
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    var events: [StopSignEvent]
    
    init(id: UUID = UUID(), userId: UUID, familyId: UUID?) {
        self.id = id
        self.userId = userId
        self.familyId = familyId
        self.startTime = Date()
        self.endTime = nil
        self.isActive = true
        self.events = []
    }
    
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
    
    var summary: DriveSummary {
        let totalStops = events.count
        let fullStops = events.filter { $0.didFullStop }.count
        let rollingStops = totalStops - fullStops
        let avgDuration = events.compactMap { $0.stopDuration }.reduce(0, +) / Double(max(totalStops, 1))
        
        return DriveSummary(
            driveId: id,
            totalStopSigns: totalStops,
            fullStops: fullStops,
            rollingStops: rollingStops,
            averageStopDuration: avgDuration,
            duration: duration ?? 0
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case documentId
        case id
        case userId
        case familyId
        case startTime
        case endTime
        case isActive
        case events
    }
}

// MARK: - Stop Sign Event

struct StopSignEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    var didFullStop: Bool
    var stopDuration: TimeInterval?
    let confidence: Float
    let location: CLLocationCoordinate2D?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), didFullStop: Bool, stopDuration: TimeInterval?, confidence: Float, location: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.didFullStop = didFullStop
        self.stopDuration = stopDuration
        self.confidence = confidence
        self.location = location
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case didFullStop
        case stopDuration
        case confidence
        case latitude
        case longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        didFullStop = try container.decode(Bool.self, forKey: .didFullStop)
        stopDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .stopDuration)
        confidence = try container.decode(Float.self, forKey: .confidence)
        
        if let lat = try? container.decode(Double.self, forKey: .latitude),
           let lon = try? container.decode(Double.self, forKey: .longitude) {
            location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            location = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(didFullStop, forKey: .didFullStop)
        try container.encodeIfPresent(stopDuration, forKey: .stopDuration)
        try container.encode(confidence, forKey: .confidence)
        
        if let location = location {
            try container.encode(location.latitude, forKey: .latitude)
            try container.encode(location.longitude, forKey: .longitude)
        }
    }
}

// MARK: - Drive Summary

struct DriveSummary: Codable {
    let driveId: UUID
    let totalStopSigns: Int
    let fullStops: Int
    let rollingStops: Int
    let averageStopDuration: TimeInterval
    let duration: TimeInterval
    
    var score: Int {
        // Perfect score is 100
        // Lose 5 points per rolling stop
        let baseScore = 100
        let penalty = rollingStops * 5
        return max(0, baseScore - penalty)
    }
    
    var grade: String {
        switch score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }
}
