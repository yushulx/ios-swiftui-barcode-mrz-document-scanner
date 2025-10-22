//
//  BarcodeOverlayView.swift
//  BarcodeDistance
//
//  Created by Xiao Ling on 10/22/25.
//

import SwiftUI

struct BarcodeOverlayView: View {
    let barcodes: [BarcodeDetection]
    
    var body: some View {
        ZStack {
            ForEach(barcodes) { barcode in
                BarcodeAnnotationView(barcode: barcode)
            }
        }
    }
}

struct BarcodeAnnotationView: View {
    let barcode: BarcodeDetection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Barcode type badge
            Text(barcode.type)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
            
            // Barcode value
            Text(barcode.value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(6)
                .lineLimit(2)
            
            // Distance
            HStack(spacing: 4) {
                Image(systemName: "ruler")
                    .font(.caption)
                Text(formatDistance(barcode.distance))
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
        }
        .position(x: barcode.position.x, y: barcode.position.y)
        .overlay(
            // Bounding box
            Rectangle()
                .stroke(Color.green, lineWidth: 2)
                .frame(width: barcode.bounds.width, height: barcode.bounds.height)
                .position(x: barcode.bounds.midX, y: barcode.bounds.midY)
        )
    }
    
    private func formatDistance(_ distance: Float) -> String {
        if distance < 1.0 {
            return String(format: "%.0f cm", distance * 100)
        } else {
            return String(format: "%.2f m", distance)
        }
    }
}

#Preview {
    let sampleBarcodes = [
        BarcodeDetection(
            value: "123456789",
            type: "QR Code",
            distance: 0.75,
            position: CGPoint(x: 200, y: 300),
            bounds: CGRect(x: 150, y: 250, width: 100, height: 100)
        )
    ]
    
    return BarcodeOverlayView(barcodes: sampleBarcodes)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.3))
}
