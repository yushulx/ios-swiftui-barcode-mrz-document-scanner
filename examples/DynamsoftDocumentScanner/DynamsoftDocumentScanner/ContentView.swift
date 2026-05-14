import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DocumentScannerStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.93, blue: 0.88), Color(red: 0.89, green: 0.84, blue: 0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch store.route {
            case .scanner:
                ScannerScreen()
            case .results:
                ResultsScreen()
            case .sort:
                SortPagesScreen()
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: store.route)
        .sheet(isPresented: $store.showSettings) {
            AutoCaptureSettingsSheet()
        }
        .sheet(item: $store.sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .sheet(item: $store.editorTarget) { _ in
            if let page = store.editorPage {
                QuadEditorSheet(page: page) { quad in
                    store.applyEditedQuad(quad)
                } onCancel: {
                    store.dismissEditor()
                }
            }
        }
        .alert("Scanner", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    store.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DocumentScannerStore())
}
