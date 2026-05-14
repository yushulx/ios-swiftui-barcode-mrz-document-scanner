import SwiftUI
import PhotosUI

struct ScannerScreen: View {
    @EnvironmentObject private var store: DocumentScannerStore
    @State private var manualCaptureToken = 0
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.retakePageIndex == nil ? "Scan Documents" : "Retake Page")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.19, green: 0.15, blue: 0.11))

                    Text(store.retakePageIndex == nil ? "SwiftUI port of the Android multi-page workflow." : "The next capture replaces the current page.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.30, blue: 0.22).opacity(0.85))
                }

                Spacer()

                Button {
                    store.showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.12))
                        .padding(14)
                        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ZStack(alignment: .topLeading) {
                CameraScannerView(manualCaptureToken: manualCaptureToken, settings: store.autoCaptureSettings)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.16), radius: 24, y: 18)

                if store.autoCaptureFlashVisible {
                    Text("Auto captured")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.88, green: 0.39, blue: 0.17), in: Capsule())
                        .padding(18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 18) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Import", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.26, green: 0.19, blue: 0.14))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Spacer()

                Button {
                    manualCaptureToken += 1
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 86, height: 86)
                        .overlay {
                            Circle()
                                .stroke(Color(red: 0.88, green: 0.39, blue: 0.17), lineWidth: 8)
                                .padding(6)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    store.openResults()
                } label: {
                    Label("Next", systemImage: "arrow.right")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(store.pages.isEmpty ? Color.gray : Color.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            (store.pages.isEmpty ? Color.white.opacity(0.64) : Color(red: 0.88, green: 0.39, blue: 0.17)),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }
                .disabled(store.pages.isEmpty)
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Pages")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.22, green: 0.17, blue: 0.12))
                    Spacer()
                    Text("\(store.pages.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.88, green: 0.39, blue: 0.17))
                }

                if store.pages.isEmpty || store.retakePageIndex != nil {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.56))
                        .frame(height: 84)
                        .overlay {
                            Text(store.retakePageIndex == nil ? "Captured pages appear here." : "Retake mode hides the page strip until the replacement is captured.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.28))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                        }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                                ThumbnailCard(page: page, index: index + 1) {
                                    store.openResults(from: index)
                                } onRemove: {
                                    store.removePage(id: page.id)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .onChange(of: selectedPhotoItem) { newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        store.importPhotoData(data)
                    }
                } else {
                    await MainActor.run {
                        store.errorMessage = "Unable to load the selected photo."
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
    }
}

struct ThumbnailCard: View {
    let page: ScannedPage
    let index: Int
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    if let image = page.renderedImage() {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 82, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.72))
                            .frame(width: 82, height: 112)
                    }

                    Text("Page \(index)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.22, green: 0.17, blue: 0.12))
                }
                .padding(10)
                .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.81, green: 0.28, blue: 0.20), .white)
            }
            .offset(x: 8, y: -8)
        }
    }
}

struct ResultsScreen: View {
    @EnvironmentObject private var store: DocumentScannerStore

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Pages")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.19, green: 0.15, blue: 0.11))

                    Text(store.pages.isEmpty ? "No pages yet." : "Page \(store.selectedPageIndex + 1) of \(store.pages.count)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.30, blue: 0.22).opacity(0.85))
                }

                Spacer()

                Menu {
                    Button("Export PDF") {
                        store.exportPDF()
                    }
                    Button("Export Images") {
                        store.exportImages()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.12))
                        .padding(14)
                        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if store.pages.isEmpty {
                Spacer()
                Text("Capture a page before reviewing results.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.40, green: 0.30, blue: 0.22))
                Spacer()
            } else {
                TabView(selection: $store.selectedPageIndex) {
                    ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                        ZoomablePageView(page: page)
                            .tag(index)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 12) {
                    ActionChip(title: "Continue", systemImage: "plus.viewfinder") {
                        store.continueScanning()
                    }
                    ActionChip(title: "Retake", systemImage: "camera.rotate") {
                        store.startRetake()
                    }
                    ActionChip(title: "Edit", systemImage: "crop") {
                        store.presentEditor()
                    }
                    .disabled(!(store.currentPage?.canEdit ?? false))
                    ActionChip(title: "Rotate", systemImage: "rotate.right") {
                        store.rotateSelectedPage()
                    }
                    ActionChip(title: "Sort", systemImage: "square.grid.2x2") {
                        store.route = .sort
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 10) {
                    ForEach(DocumentColorMode.allCases) { mode in
                        Button {
                            store.setColorMode(mode)
                        } label: {
                            Text(mode.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle((store.currentPage?.colorMode == mode) ? .white : Color(red: 0.34, green: 0.26, blue: 0.18))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    (store.currentPage?.colorMode == mode ? Color(red: 0.88, green: 0.39, blue: 0.17) : Color.white.opacity(0.78)),
                                    in: Capsule()
                                )
                        }
                    }
                }
                .padding(.bottom, 18)
            }
        }
    }
}

struct ZoomablePageView: View {
    let page: ScannedPage

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.82))

            if let image = page.renderedImage() {
                GeometryReader { proxy in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .padding(18)
            } else {
                Text("Unable to render page preview.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.28))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.66), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 20, y: 12)
    }
}

struct ActionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.28, green: 0.20, blue: 0.14))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SortPagesScreen: View {
    @EnvironmentObject private var store: DocumentScannerStore

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sort Pages")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.19, green: 0.15, blue: 0.11))
                    Text("Drag to reorder the capture stack.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.30, blue: 0.22).opacity(0.85))
                }

                Spacer()

                Button("Done") {
                    store.route = .results
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.88, green: 0.39, blue: 0.17), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            List {
                ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                    HStack(spacing: 14) {
                        if let image = page.renderedImage() {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Page \(index + 1)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.12))
                            Text(page.canEdit ? "Editable quad preserved" : "Imported as flat image")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.42, green: 0.33, blue: 0.26))
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.white.opacity(0.76))
                }
                .onMove(perform: store.movePages)
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
    }
}