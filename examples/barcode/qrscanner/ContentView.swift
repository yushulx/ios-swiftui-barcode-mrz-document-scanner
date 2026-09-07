//
//  ContentView.swift
//  qrscanner
//
//  Created by xiao on 2022/2/23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var cameraManager = CameraManager()
    @ObservedObject private var licenseState = LicenseState.shared

    var body: some View {
        ZStack {
            DynamsoftCameraView(cameraManager: cameraManager)
                .ignoresSafeArea()
                .onAppear() {
                    cameraManager.viewDidAppear()
                }.onDisappear(){
                    cameraManager.viewDidDisappear()
                }

            VStack {
                Text("iOS QR Code Scanner")
                    .font(.title)
                    .foregroundColor(.orange)
                    .padding(.top, 8)

                Spacer()
            }
        }
        .alert("License Error", isPresented: $licenseState.isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(licenseState.errorMessage)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
