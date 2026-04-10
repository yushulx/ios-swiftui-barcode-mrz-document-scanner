//
//  ContentView.swift
//  BarcodeBenchmark
//
//  Main navigation container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: BenchmarkViewModel
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .imageBenchmark:
                        ImageBenchmarkView()
                    case .videoBenchmark:
                        VideoBenchmarkView()
                    case .dynamsoftScanner:
                        DynamsoftScannerView()
                    case .mlkitScanner:
                        MLKitScannerView()
                    case .visionScanner:
                        VisionScannerView()
                    case .results:
                        BenchmarkResultView()
                    }
                }
        }
        .environmentObject(viewModel)
    }
}

// MARK: - Navigation Routes
enum Route: Hashable {
    case imageBenchmark
    case videoBenchmark
    case dynamsoftScanner
    case mlkitScanner
    case visionScanner
    case results
}

#Preview {
    ContentView()
        .environmentObject(BenchmarkViewModel())
}
