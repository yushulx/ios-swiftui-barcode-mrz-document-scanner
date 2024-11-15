//
//  ContentView.swift
//  MrzScanner
//
//  Created by Xiao Ling on 11/14/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                NavigationLink(destination:CaptureView(title: "Scan MRZ")) {
                    Text("Scan MRZ")
                        .font(.title2)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
