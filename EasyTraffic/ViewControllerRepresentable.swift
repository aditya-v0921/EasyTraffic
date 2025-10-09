//
//  ViewControllerRepresentable.swift
//  EasyTraffic
//
//  Created by Aditya Vaswani on 7/12/24.
//

import SwiftUI
import UIKit

struct ViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ViewController {
        ViewController()
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // Update the UI controller if needed
    }
}
