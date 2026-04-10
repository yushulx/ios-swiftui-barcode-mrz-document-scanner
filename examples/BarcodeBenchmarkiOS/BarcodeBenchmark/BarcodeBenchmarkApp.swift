//
//  BarcodeBenchmarkApp.swift
//  BarcodeBenchmark
//
//  iOS Barcode Benchmark App - Compares Dynamsoft, MLKit, and Apple Vision
//

import SwiftUI

@main
struct BarcodeBenchmarkApp: App {
    @StateObject private var viewModel = BenchmarkViewModel()
    
    init() {
        // Initialize Dynamsoft license
        DynamsoftLicenseManager.initLicense("DLS2eyJoYW5kc2hha2VDb2RlIjoiMjM0ODEwLU1qTTBPREV3TFZSeWFXRnNVSEp2YWciLCJtYWluU2VydmVyVVJMIjoiaHR0cHM6Ly9tZGxzLmR5bmFtc29mdG9ubGluZS5jb20vIiwib3JnYW5pemF0aW9uSUQiOiIyMzQ4MTAiLCJzdGFuZGJ5U2VydmVyVVJMIjoiaHR0cHM6Ly9zZGxzLmR5bmFtc29mdG9ubGluZS5jb20vIiwiY2hlY2tDb2RlIjoxNzYwOTE2OTkyfQ==")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Dynamsoft License Manager
class DynamsoftLicenseManager {
    static func initLicense(_ license: String) {
        // Note: In actual implementation, this would call the Dynamsoft SDK
        // For now, this is a placeholder for license initialization
        print("Initializing Dynamsoft license...")
    }
}
