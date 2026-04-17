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
        
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !apiKey.isEmpty {
            GMSServices.provideAPIKey(apiKey)
        } else {
            print("Google Maps API key is missing. Add GMSApiKey to Info.plist.")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
// Path for cd: $ cd /Users/adi/Desktop/EasyTraffic
