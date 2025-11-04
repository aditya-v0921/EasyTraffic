//
//  HomeScreenView.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 8/14/24.
//

import Foundation
import SwiftUI

struct HomeScreenView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to EasyTraffic")
                    .font(.largeTitle)
                    .padding()
                    
                Text("Position your phone on the dashboard and click the button to start.")
                    .font(.body)
                    .padding()
                    
                NavigationLink(destination: CameraView()) {
                    Text("Start Camera")
                        .font(.title)
                        .padding()
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}
