import SwiftUI

struct ContentView: View {
    @State private var detectedBarcodes: [BarcodeDetection] = []
    @State private var showingInfo = false
    
    var body: some View {
        ZStack {
            // AR Camera View
            ARBarcodeScanner(detectedBarcodes: $detectedBarcodes)
                .edgesIgnoringSafeArea(.all)
            
            // Barcode Overlay
            BarcodeOverlayView(barcodes: detectedBarcodes)
                .edgesIgnoringSafeArea(.all)
            
            // UI Controls
            VStack {
                // Top Bar
                HStack {
                    Text("Barcode Distance Scanner")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Button(action: {
                        showingInfo.toggle()
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom Status Bar
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .foregroundColor(.white)
                    
                    if detectedBarcodes.isEmpty {
                        Text("Point camera at a barcode")
                            .foregroundColor(.white)
                    } else {
                        Text("\(detectedBarcodes.count) barcode(s) detected")
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(detectedBarcodes.isEmpty ? Color.red : Color.green)
                        .frame(width: 12, height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding()
            }
        }
        .sheet(isPresented: $showingInfo) {
            InfoView()
        }
    }
}

struct InfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("How to use:")
                        .font(.headline)
                    
                    Text("1. Point your iPhone camera at a barcode")
                    Text("2. The app will automatically detect and scan the barcode")
                    Text("3. Distance from your iPhone to the barcode will be displayed in real-time")
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical)
                
                Group {
                    Text("Supported Barcode Types:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• QR Code")
                            Text("• Code 128")
                            Text("• Code 39")
                            Text("• Code 93")
                            Text("• EAN-8 / EAN-13")
                            Text("• UPC-E")
                            Text("• PDF417")
                            Text("• Aztec")
                            Text("• Data Matrix")
                            Text("• And more...")
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                Text("Distance measurement uses ARKit for accurate real-time depth detection.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
