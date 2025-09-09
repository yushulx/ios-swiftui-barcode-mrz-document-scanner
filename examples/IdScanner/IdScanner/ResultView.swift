import SwiftUI
import Photos

struct ResultView: View {
    let image: UIImage
    let ocrResults: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var showingImageDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image section
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 300)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .onTapGesture {
                            showingImageDetail = true
                        }
                }
                .padding()
                
                // OCR Results section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                            .foregroundColor(.blue)
                        Text("Extracted Text")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(ocrResults.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    if ocrResults.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No text detected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        List {
                            ForEach(Array(ocrResults.enumerated()), id: \.offset) { index, text in
                                OCRResultRow(text: text, index: index + 1)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: shareImage) {
                            Label("Share Image", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: shareText) {
                            Label("Share Text", systemImage: "text.badge.plus")
                        }
                        
                        Button(action: saveToPhotos) {
                            Label("Save to Photos", systemImage: "photo.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingImageDetail) {
            ImageDetailView(image: image)
        }
    }
    
    private func shareImage() {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func shareText() {
        let combinedText = ocrResults.joined(separator: "\n")
        let activityVC = UIActivityViewController(activityItems: [combinedText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func saveToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    UIImageWriteToSavedPhotosAlbum(self.image, nil, nil, nil)
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                case .denied, .restricted:
                    // Handle permission denied
                    print("Photo library access denied")
                default:
                    break
                }
            }
        }
    }
}

struct OCRResultRow: View {
    let text: String
    let index: Int
    @State private var isCopied = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                
                if text.count > 50 {
                    Text("\(text.count) characters")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: copyText) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(isCopied ? .green : .blue)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            copyText()
        }
    }
    
    private func copyText() {
        UIPasteboard.general.string = text
        isCopied = true
        
        // Reset the copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

struct ImageDetailView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale < 1 {
                                            withAnimation(.spring()) {
                                                scale = 1
                                                lastScale = 1
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        } else if scale > 5 {
                                            withAnimation(.spring()) {
                                                scale = 5
                                                lastScale = 5
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationTitle("Image Detail")
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
    ResultView(
        image: UIImage(systemName: "doc.text") ?? UIImage(),
        ocrResults: [
            "DRIVER LICENSE",
            "John Doe",
            "123 Main Street",
            "Anytown, ST 12345",
            "DOB: 01/15/1990",
            "License #: D123456789"
        ]
    )
}
