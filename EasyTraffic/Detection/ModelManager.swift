//
//  ModelManager.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 7/19/24.
//

import Foundation
import Vision

class ModelManager {
    static let shared = ModelManager()
    var model: VNCoreMLModel?

    private init() {
        loadModel()
    }

    private func loadModel() {
        do {
            model = try VNCoreMLModel(for: SS1().model)
        } catch {
            print("Error loading the Core ML model: \(error)")
        }
    }

    func getCoreMLModel() -> VNCoreMLModel? {
        return model
    }
}
