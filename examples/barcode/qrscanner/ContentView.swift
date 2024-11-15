//
//  ContentView.swift
//  qrscanner
//
//  Created by xiao on 2022/2/23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var cameraManager = CameraManager(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
    
    var body: some View {
        ZStack() {
            DynamsoftCameraView(cameraManager: cameraManager).onAppear() {
                cameraManager.viewDidAppear()
            }.onDisappear(){
                cameraManager.viewDidDisappear()
            }
            VStack {
                Text("iOS QR Code Scanner").font(.title).foregroundColor(.orange)
                Spacer()
            }
            
//            Text(cameraManager.results).font(.subheadline).foregroundColor(.blue).fontWeight(.heavy)
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
