//
//  EasyTrafficApp.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 6/30/24.
//

import SwiftUI
import Firebase

@main
struct EasyTrafficApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
// Path for cd: $ cd /Users/adi/Desktop/EasyTraffic
