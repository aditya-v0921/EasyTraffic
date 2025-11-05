//
//  DetectionModels.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 10/16/25.
//

import Foundation
import CoreGraphics

// MARK: - Detection Models

struct DetectedObject {
    let bbox: CGRect // normalized [0,1] in image space
    let confidence: Float
    let label: String
    let timestamp: Date
}

// MARK: - Stability Gate

final class StabilityGate {
    private var hits = 0
    var needed = 4
    
    func update(present: Bool) -> Bool {
        hits = present ? hits + 1 : 0
        return hits >= needed
    }
}

// MARK: - Deduper

final class Deduper {
    private var lastAnnounced: DetectedObject?
    
    private func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        guard !inter.isNull else { return 0 }
        let interArea = inter.width * inter.height
        let unionArea = a.width * a.height + b.width * b.height - interArea
        return unionArea > 0 ? interArea / unionArea : 0
    }
    
    func isNewObject(_ obj: DetectedObject,
                     label: String,
                     minConfidence: Float = 0.8,
                     maxSpatialOverlapForNew: CGFloat = 0.35,
                     forgetAfter: TimeInterval = 10.0) -> Bool {
        guard obj.confidence >= minConfidence else { return false }
        if let last = lastAnnounced,
           Date().timeIntervalSince(last.timestamp) > forgetAfter {
            lastAnnounced = nil
        }
        guard let last = lastAnnounced, last.label == label else {
            lastAnnounced = obj
            return true
        }
        // If it's basically the same box, don't announce again
        if iou(last.bbox, obj.bbox) > maxSpatialOverlapForNew {
            return false
        }
        lastAnnounced = obj
        return true
    }
}

final class rollingStop {
    
}
