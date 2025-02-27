import SwiftUI

struct ImageViewer: View {
    var image: NSImage
    @Binding var isShowingImage: Bool

    var body: some View {
        VStack {
            imageView
                .resizable()
                .scaledToFit()
                .onTapGesture {
                    isShowingImage = false
                }
        }
        .edgesIgnoringSafeArea(.all)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Back") {
                    isShowingImage = false
                }
            }
        }
        .navigationTitle("Photo")
        .padding()
    }

    var imageView: Image {
        return Image(nsImage: image)
    }
}
