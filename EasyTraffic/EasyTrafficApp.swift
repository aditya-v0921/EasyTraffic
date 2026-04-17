//
//  EasyTrafficApp.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 6/30/24.
//

import SwiftUI
import Firebase
import GoogleMaps

@main
struct EasyTrafficApp: App {
    
    init() {
        FirebaseApp.configure()
        
        let plistKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
        let environmentKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"]
        let apiKey = [plistKey, environmentKey]
            .compactMap { $0 }
            .first { !$0.isEmpty && !$0.hasPrefix("$(") }
        
        if let apiKey {
            GMSServices.provideAPIKey(apiKey)
        } else {
            print("Google Maps API key is missing. Set GOOGLE_MAPS_API_KEY locally.")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
// Path for cd: $ cd /Users/adi/Desktop/EasyTraffic
