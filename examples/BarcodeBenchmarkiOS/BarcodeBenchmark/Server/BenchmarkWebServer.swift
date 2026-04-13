//
//  BenchmarkWebServer.swift
//  BarcodeBenchmark
//
//  Embedded HTTP server for remote benchmarking
//

import Foundation
import Network
import UIKit
import AVFoundation

class BenchmarkWebServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    // Per-connection accumulation buffer (connection object id → Data)
    private var buffers: [ObjectIdentifier: Data] = [:]
    private let port: UInt16
    private weak var viewModel: BenchmarkViewModel?
    private let queue = DispatchQueue(label: "com.dynamsoft.webserver", qos: .utility)
    // Thread-safe video progress (read/written from async tasks and queue callbacks)
    private let progressLock = NSLock()
    private var _videoProgressJSON: String = "{\"isActive\":false}"
    private var videoProgressJSON: String {
        get { progressLock.withLock { _videoProgressJSON } }
        set { progressLock.withLock { _videoProgressJSON = newValue } }
    }
    
    init(port: UInt16, viewModel: BenchmarkViewModel) throws {
        self.port = port
        self.viewModel = viewModel
        
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.invalidPort
        }
        
        let parameters = NWParameters.tcp
        listener = try NWListener(using: parameters, on: port)
    }
    
    func start() throws {
        guard let listener = listener else {
            throw ServerError.notInitialized
        }
        
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                break
            case .failed(_):
                break
            default:
                break
            }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener.start(queue: queue)
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        buffers[ObjectIdentifier(connection)] = Data()

        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.removeConnection(connection)
            }
        }

        connection.start(queue: queue)
        receiveData(from: connection)
    }

    private func removeConnection(_ connection: NWConnection) {
        connection.cancel()
        buffers.removeValue(forKey: ObjectIdentifier(connection))
        connections.removeAll { $0 === connection }
    }

    // MARK: - Buffered receive
    // Accumulates chunks until the entire HTTP message (headers + body) is available.
    // maximumLength is capped per-call; we loop until Content-Length is fully satisfied.
    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.removeConnection(connection)
                return
            }

            if let data = data, !data.isEmpty {
                let key = ObjectIdentifier(connection)
                self.buffers[key, default: Data()].append(data)
            }

            let key = ObjectIdentifier(connection)
            let buffer = self.buffers[key] ?? Data()

            if self.isRequestComplete(buffer) {
                self.buffers.removeValue(forKey: key)
                self.dispatch(buffer: buffer, connection: connection)
            } else if isComplete {
                self.buffers.removeValue(forKey: key)
                self.dispatch(buffer: buffer, connection: connection)
            } else {
                self.receiveData(from: connection)
            }
        }
    }

    /// Returns true when the full HTTP message (headers + declared body) has been received.
    private func isRequestComplete(_ data: Data) -> Bool {
        let sep = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        guard let sepRange = data.range(of: sep) else { return false }
        let bodyStart = sepRange.upperBound
        guard let headerStr = String(data: data[..<sepRange.lowerBound], encoding: .utf8) else { return false }

        // Iterate over header lines to find Content-Length (no cross-string index use).
        for line in headerStr.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count)
                    .trimmingCharacters(in: .whitespaces)
                if let contentLength = Int(value) {
                    let needed = bodyStart + contentLength
                    return data.count >= needed
                }
            }
        }
        // No Content-Length — headers-only request, already complete.
        return true
    }

    private func dispatch(buffer: Data, connection: NWConnection) {
        // Parse request line from header portion only.
        let headerSeparator = Data([0x0D, 0x0A, 0x0D, 0x0A])
        let headerData: Data
        if let sepRange = buffer.range(of: headerSeparator) {
            headerData = buffer[..<sepRange.lowerBound]
        } else {
            headerData = buffer
        }
        guard let headerStr = String(data: headerData, encoding: .utf8) else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", connection: connection)
            return
        }

        let lines = headerStr.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", connection: connection)
            return
        }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", connection: connection)
            return
        }

        let method = parts[0]
        let path   = parts[1]

        switch (method, path) {
        case ("GET", "/"), ("GET", "/index.html"):
            sendHTMLResponse(getIndexHtml(), connection: connection)
        case ("GET", "/styles.css"):
            sendCSSResponse(getStylesCss(), connection: connection)
        case ("GET", "/app.js"):
            sendJSResponse(getAppJs(), connection: connection)
        case ("GET", "/api/config"):
            let config = "{\"showBenchmarkTime\": \(BenchmarkConfig.showBenchmarkTime)}"
            sendJSONResponse(config, connection: connection)
        case ("GET", "/api/status"):
            let status = "{\"status\":\"running\",\"dynamsoft\":true,\"mlkit\":true,\"vision\":true,\"zxingcpp\":true}"
            sendJSONResponse(status, connection: connection)
        case ("GET", "/api/video-progress"):
            sendJSONResponse(videoProgressJSON, connection: connection)
        case ("POST", "/api/benchmark"):
            handleBenchmarkRequest(headers: headerStr, body: buffer, connection: connection)
        default:
            sendResponse("HTTP/1.1 404 Not Found\r\n\r\n", connection: connection)
        }
    }
    
    // MARK: - Benchmark request
    private func handleBenchmarkRequest(headers: String, body: Data, connection: NWConnection) {
        guard let boundary = multipartBoundary(from: headers) else {
            sendJSONResponse("{\"error\":\"Missing multipart boundary\"}", connection: connection)
            return
        }

        guard let fileData = extractFilePart(from: body, boundary: boundary) else {
            sendJSONResponse("{\"error\":\"Could not extract file part\"}", connection: connection)
            return
        }

        // Determine type from the 'fileType' text field in the form, or fall back to sniffing bytes.
        let fileTypeField = extractTextField(named: "fileType", from: body, boundary: boundary) ?? ""
        let isVideo = fileTypeField.hasPrefix("video") || isVideoData(fileData)

        guard let vm = viewModel else {
            sendJSONResponse("{\"error\":\"Server not ready\"}", connection: connection)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let (dynDet, mlDet, visDet, zxDet) = await MainActor.run {
                (vm.dynamsoftDetector, vm.mlkitDetector, vm.visionDetector, vm.zxingcppDetector)
            }

            if isVideo {
                await self.handleVideoBenchmark(fileData: fileData, dynDet: dynDet, mlDet: mlDet,
                                                visDet: visDet, zxDet: zxDet, connection: connection)
            } else {
                await self.handleImageBenchmark(fileData: fileData, dynDet: dynDet, mlDet: mlDet,
                                                visDet: visDet, zxDet: zxDet, connection: connection)
            }
        }
    }

    // MARK: - Image benchmark
    private func handleImageBenchmark(fileData: Data,
                                      dynDet: DynamsoftBarcodeDetector,
                                      mlDet: MLKitBarcodeDetector,
                                      visDet: VisionBarcodeDetector,
                                      zxDet: ZXingCppBarcodeDetector,
                                      connection: NWConnection) async {
        guard let image = UIImage(data: fileData) else {
            sendJSONResponse("{\"error\":\"Could not decode image data\"}", connection: connection)
            return
        }

        let t0 = Date()
        let dyn = (try? await dynDet.detectBarcodes(in: image)) ?? []
        let dynTime = Int(Date().timeIntervalSince(t0) * 1000)

        let t1 = Date()
        let ml  = (try? await mlDet.detectBarcodes(in: image))  ?? []
        let mlTime = Int(Date().timeIntervalSince(t1) * 1000)

        let t2 = Date()
        let vis = (try? await visDet.detectBarcodes(in: image)) ?? []
        let visTime = Int(Date().timeIntervalSince(t2) * 1000)

        let t3 = Date()
        let zx = (try? await zxDet.detectBarcodes(in: image)) ?? []
        let zxTime = Int(Date().timeIntervalSince(t3) * 1000)

        let json = buildJSON(width: Int(image.size.width), height: Int(image.size.height),
                             dyn: dyn, dynTime: dynTime,
                             ml: ml,  mlTime: mlTime,
                             vis: vis, visTime: visTime,
                             zx: zx, zxTime: zxTime)
        sendJSONResponse(json, connection: connection)
    }

    // MARK: - Video benchmark
    private func handleVideoBenchmark(fileData: Data,
                                      dynDet: DynamsoftBarcodeDetector,
                                      mlDet: MLKitBarcodeDetector,
                                      visDet: VisionBarcodeDetector,
                                      zxDet: ZXingCppBarcodeDetector,
                                      connection: NWConnection) async {
        // Write video bytes to a temp file so AVFoundation can open it.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        do {
            try fileData.write(to: tempURL)
        } catch {
            sendJSONResponse("{\"error\":\"Could not write temp video\"}", connection: connection)
            return
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let asset = AVURLAsset(url: tempURL)
        let durationSeconds: Double
        do {
            let duration = try await asset.load(.duration)
            durationSeconds = CMTimeGetSeconds(duration)
        } catch {
            sendJSONResponse("{\"error\":\"Could not read video duration\"}", connection: connection)
            return
        }

        // Sample up to 30 frames, at least 1 s apart.
        let maxFrames = 30
        let interval = max(durationSeconds / Double(maxFrames), 1.0)
        var sampleTimes: [CMTime] = []
        var t = 0.0
        while t <= durationSeconds && sampleTimes.count < maxFrames {
            sampleTimes.append(CMTime(seconds: t, preferredTimescale: 600))
            t += interval
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 0.5, preferredTimescale: 600)

        // Collect frames via the async sequence (iOS 16+).
        var frames: [(CMTime, CGImage)] = []
        for await result in generator.images(for: sampleTimes) {
            if let cgImage = try? result.image {
                frames.append((result.requestedTime, cgImage))
            }
        }

        if frames.isEmpty {
            sendJSONResponse("{\"error\":\"No frames could be extracted from video\"}", connection: connection)
            return
        }

        var dynCount = 0; var dynTotalMs = 0; var dynSeenKeys = Set<String>(); var dynBarcodes: [BarcodeInfo] = []
        var mlCount  = 0; var mlTotalMs  = 0; var mlSeenKeys  = Set<String>(); var mlBarcodes:  [BarcodeInfo] = []
        var visCount = 0; var visTotalMs = 0; var visSeenKeys = Set<String>(); var visBarcodes: [BarcodeInfo] = []
        var zxCount  = 0; var zxTotalMs  = 0; var zxSeenKeys  = Set<String>(); var zxBarcodes:  [BarcodeInfo] = []

        // Pre-extract UIImages once (shared across all SDKs)
        var width = 0; var height = 0
        var uiImages: [UIImage] = []
        for (_, cgImage) in frames {
            if width == 0 { width = cgImage.width; height = cgImage.height }
            uiImages.append(UIImage(cgImage: cgImage))
        }
        let totalF = uiImages.count

        // Helper to build progress JSON
        func progressJSON(sdk: String, frame: Int, total: Int, completedSDKs: Int) -> String {
            let pct = total > 0 ? Int((Double(completedSDKs) * Double(total) + Double(frame)) / (4.0 * Double(total)) * 100) : 0
            return "{\"isActive\":true,\"sdk\":\"\(sdk)\",\"frame\":\(frame),\"total\":\(total),\"completedSDKs\":\(completedSDKs),\"percent\":\(pct)}"
        }

        // --- Dynamsoft ---
        videoProgressJSON = progressJSON(sdk: "Dynamsoft", frame: 0, total: totalF, completedSDKs: 0)
        for (i, img) in uiImages.enumerated() {
            let t0 = Date()
            let d = (try? await dynDet.detectBarcodes(in: img)) ?? []
            dynTotalMs += Int(Date().timeIntervalSince(t0) * 1000)
            for b in d { dynCount += 1; if dynSeenKeys.insert("\(b.format):\(b.text)").inserted { dynBarcodes.append(b) } }
            videoProgressJSON = progressJSON(sdk: "Dynamsoft", frame: i + 1, total: totalF, completedSDKs: 0)
        }

        // --- MLKit ---
        videoProgressJSON = progressJSON(sdk: "MLKit", frame: 0, total: totalF, completedSDKs: 1)
        for (i, img) in uiImages.enumerated() {
            let t0 = Date()
            let m = (try? await mlDet.detectBarcodes(in: img)) ?? []
            mlTotalMs += Int(Date().timeIntervalSince(t0) * 1000)
            for b in m { mlCount += 1; if mlSeenKeys.insert("\(b.format):\(b.text)").inserted { mlBarcodes.append(b) } }
            videoProgressJSON = progressJSON(sdk: "MLKit", frame: i + 1, total: totalF, completedSDKs: 1)
        }

        // --- Apple Vision ---
        videoProgressJSON = progressJSON(sdk: "Apple Vision", frame: 0, total: totalF, completedSDKs: 2)
        for (i, img) in uiImages.enumerated() {
            let t0 = Date()
            let v = (try? await visDet.detectBarcodes(in: img)) ?? []
            visTotalMs += Int(Date().timeIntervalSince(t0) * 1000)
            for b in v { visCount += 1; if visSeenKeys.insert("\(b.format):\(b.text)").inserted { visBarcodes.append(b) } }
            videoProgressJSON = progressJSON(sdk: "Apple Vision", frame: i + 1, total: totalF, completedSDKs: 2)
        }

        // --- ZXing-CPP ---
        videoProgressJSON = progressJSON(sdk: "ZXing-CPP", frame: 0, total: totalF, completedSDKs: 3)
        for (i, img) in uiImages.enumerated() {
            let t0 = Date()
            let z = (try? await zxDet.detectBarcodes(in: img)) ?? []
            zxTotalMs += Int(Date().timeIntervalSince(t0) * 1000)
            for b in z { zxCount += 1; if zxSeenKeys.insert("\(b.format):\(b.text)").inserted { zxBarcodes.append(b) } }
            videoProgressJSON = progressJSON(sdk: "ZXing-CPP", frame: i + 1, total: totalF, completedSDKs: 3)
        }

        videoProgressJSON = "{\"isActive\":false}"

        let json = """
        {
            "width": \(width), "height": \(height),
            "frames": \(frames.count),
            "dynamsoft": {"count": \(dynCount), "timeMs": \(dynTotalMs), "barcodes": \(jsonBarcodes(dynBarcodes))},
            "mlkit":     {"count": \(mlCount),  "timeMs": \(mlTotalMs),  "barcodes": \(jsonBarcodes(mlBarcodes))},
            "vision":    {"count": \(visCount), "timeMs": \(visTotalMs), "barcodes": \(jsonBarcodes(visBarcodes))},
            "zxingcpp":  {"count": \(zxCount),  "timeMs": \(zxTotalMs),  "barcodes": \(jsonBarcodes(zxBarcodes))}
        }
        """
        sendJSONResponse(json, connection: connection)
    }

    // MARK: - JSON builder
    private func buildJSON(width: Int, height: Int,
                           dyn: [BarcodeInfo], dynTime: Int,
                           ml:  [BarcodeInfo], mlTime:  Int,
                           vis: [BarcodeInfo], visTime: Int,
                           zx:  [BarcodeInfo], zxTime:  Int) -> String {
        return """
        {
            "width": \(width), "height": \(height),
            "dynamsoft": {"count": \(dyn.count), "timeMs": \(dynTime), "barcodes": \(jsonBarcodes(dyn))},
            "mlkit":     {"count": \(ml.count),  "timeMs": \(mlTime),  "barcodes": \(jsonBarcodes(ml))},
            "vision":    {"count": \(vis.count), "timeMs": \(visTime), "barcodes": \(jsonBarcodes(vis))},
            "zxingcpp":  {"count": \(zx.count),  "timeMs": \(zxTime),  "barcodes": \(jsonBarcodes(zx))}
        }
        """
    }

    private func jsonBarcodes(_ list: [BarcodeInfo]) -> String {
        let items = list.map { b -> String in
            let t = b.text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            return "{\"format\":\"\(b.format)\",\"text\":\"\(t)\"}"
        }
        return "[" + items.joined(separator: ",") + "]"
    }

    // MARK: - Multipart helpers

    /// Extracts the multipart boundary value from the Content-Type header line.
    /// Uses line-based parsing to avoid Swift cross-string index pitfalls.
    private func multipartBoundary(from headers: String) -> String? {
        for line in headers.components(separatedBy: "\r\n") {
            guard line.lowercased().hasPrefix("content-type:") else { continue }
            let value = line.dropFirst("content-type:".count)
                .trimmingCharacters(in: .whitespaces)
            guard value.lowercased().contains("multipart") else { continue }
            for part in value.components(separatedBy: ";") {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("boundary=") {
                    return String(trimmed.dropFirst("boundary=".count))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }
        }
        return nil
    }

    /// Extracts the raw bytes of the first multipart part that has a `filename=` attribute.
    private func extractFilePart(from data: Data, boundary: String) -> Data? {
        return extractPart(from: data, boundary: boundary, matching: { hdr in
            hdr.lowercased().contains("filename=")
        })
    }

    /// Extracts the string value of a named non-file form field.
    private func extractTextField(named name: String, from data: Data, boundary: String) -> String? {
        guard let raw = extractPart(from: data, boundary: boundary, matching: { hdr in
            hdr.lowercased().contains("name=\"\(name.lowercased())\"") &&
            !hdr.lowercased().contains("filename=")
        }) else { return nil }
        return String(data: raw, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPart(from data: Data, boundary: String,
                             matching: (String) -> Bool) -> Data? {
        guard let boundaryBytes = ("--" + boundary).data(using: .utf8),
              let crlf          = "\r\n".data(using: .utf8),
              let headerSep     = "\r\n\r\n".data(using: .utf8) else { return nil }

        var searchStart = data.startIndex
        while let bStart = data.range(of: boundaryBytes, in: searchStart..<data.endIndex) {
            // The part headers begin after the boundary line's trailing CRLF.
            let hdrStart = data.index(bStart.upperBound,
                                      offsetBy: crlf.count,
                                      limitedBy: data.endIndex) ?? bStart.upperBound
            guard let hdrEnd = data.range(of: headerSep, in: hdrStart..<data.endIndex) else { break }

            if let hdrStr = String(data: data[hdrStart..<hdrEnd.lowerBound], encoding: .utf8),
               matching(hdrStr) {
                let bodyStart = hdrEnd.upperBound
                if let nextB = data.range(of: boundaryBytes, in: bodyStart..<data.endIndex) {
                    // Strip the trailing CRLF before the next boundary marker.
                    let bodyEnd = nextB.lowerBound >= crlf.count
                        ? data.index(nextB.lowerBound, offsetBy: -crlf.count)
                        : nextB.lowerBound
                    return data[bodyStart..<bodyEnd]
                }
                return data[bodyStart...]
            }
            searchStart = bStart.upperBound
        }
        return nil
    }

    /// Sniff the first 12 bytes to detect common video container signatures.
    private func isVideoData(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let header = Array(data.prefix(12))
        // ftyp box (MP4/MOV): bytes 4-7 == "ftyp"
        if header.count >= 8,
           header[4] == 0x66, header[5] == 0x74, header[6] == 0x79, header[7] == 0x70 {
            return true
        }
        // RIFF/AVI: bytes 0-3 == "RIFF"
        if header[0] == 0x52, header[1] == 0x49, header[2] == 0x46, header[3] == 0x46 {
            return true
        }
        return false
    }
    
    private func sendHTMLResponse(_ content: String, connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: text/html\r\n\
        Content-Length: \(content.utf8.count)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        \r\n\
        \(content)
        """
        sendResponse(response, connection: connection)
    }
    
    private func sendCSSResponse(_ content: String, connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: text/css\r\n\
        Content-Length: \(content.utf8.count)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        \r\n\
        \(content)
        """
        sendResponse(response, connection: connection)
    }
    
    private func sendJSResponse(_ content: String, connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: application/javascript\r\n\
        Content-Length: \(content.utf8.count)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        \r\n\
        \(content)
        """
        sendResponse(response, connection: connection)
    }
    
    private func sendJSONResponse(_ content: String, connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: application/json\r\n\
        Content-Length: \(content.utf8.count)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        \r\n\
        \(content)
        """
        sendResponse(response, connection: connection)
    }
    
    private func sendResponse(_ response: String, connection: NWConnection) {
        guard let data = response.data(using: .utf8) else { return }
        
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            self?.removeConnection(connection)
        })
    }
    
    // MARK: - HTML Content
    private func getIndexHtml() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Barcode Benchmark</title>
            <link rel="stylesheet" href="/styles.css">
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>🔍 Barcode Benchmark</h1>
                    <p>Compare Dynamsoft vs MLKit vs Apple Vision vs ZXing-CPP</p>
                </header>
                
                <div class="upload-section">
                    <div class="file-type-selector">
                        <label>
                            <input type="radio" name="fileType" value="image" checked>
                            <span class="radio-btn">📷 Images</span>
                        </label>
                        <label>
                            <input type="radio" name="fileType" value="video">
                            <span class="radio-btn">🎬 Video</span>
                        </label>
                    </div>
                    
                    <div class="drop-zone" id="dropZone">
                        <div class="drop-zone-content">
                            <span class="drop-icon">📁</span>
                            <p>Drag & drop files or folders here</p>
                            <p class="hint">Supports multiple images or a folder</p>
                            <p class="or">or</p>
                            <button class="browse-btn" id="browseBtn">Browse Files</button>
                        </div>
                        <input type="file" id="fileInput" accept="image/*,video/*" multiple hidden>
                    </div>
                    
                    <div class="file-list" id="fileList" style="display: none;">
                        <div class="file-list-header">
                            <span id="fileCount">0 files selected</span>
                            <button class="clear-btn" id="clearBtn">Clear All</button>
                        </div>
                        <div class="file-items" id="fileItems"></div>
                    </div>
                    
                    <button class="benchmark-btn" id="benchmarkBtn" disabled>Run Benchmark</button>
                </div>
                
                <div class="progress-section" id="progressSection" style="display: none;">
                    <div class="progress-header">
                        <span id="progressText">Processing...</span>
                        <span id="progressCount">0/0</span>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill" id="progressFill"></div>
                    </div>
                    <div class="current-file" id="currentFile"></div>
                    <div class="video-progress" id="videoProgress" style="display:none;">
                        <div class="vp-label" id="vpLabel">Analyzing SDK...</div>
                        <div class="vp-frames" id="vpFrames">Frame 0 / 0</div>
                        <div class="vp-bar-wrap"><div class="vp-bar-fill" id="vpBarFill"></div></div>
                    </div>
                    <div id="videoPreviewBox" style="display:none; text-align:center; margin-top:16px;">
                        <video id="videoPlayer" autoplay muted loop controls
                               style="max-width:100%; max-height:280px; border-radius:10px; background:#000;"></video>
                    </div>
                </div>
                
                <div class="results" id="results" style="display: none;">
                    <div class="results-header">
                        <h2>Batch Benchmark Results</h2>
                        <button class="export-btn" id="exportBtn">📄 Export Report</button>
                    </div>
                    <div class="batch-summary" id="batchSummary"></div>
                    <div class="batch-results" id="batchResults"></div>
                </div>
                
                <footer>
                    <p>Powered by iOS • Barcode Benchmark App</p>
                </footer>
            </div>
            <script src="/app.js"></script>
        </body>
        </html>
        """
    }
    
    // MARK: - CSS Content
    private func getStylesCss() -> String {
        return """
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: #fff;
        }
        .container { max-width: 1000px; margin: 0 auto; padding: 40px 20px; }
        header { text-align: center; margin-bottom: 40px; }
        header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        header p { color: #888; font-size: 1.1rem; }
        .upload-section {
            background: rgba(255,255,255,0.05);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
        }
        .file-type-selector {
            display: flex;
            gap: 15px;
            justify-content: center;
            margin-bottom: 25px;
        }
        .file-type-selector label { cursor: pointer; }
        .file-type-selector input { display: none; }
        .radio-btn {
            display: inline-block;
            padding: 12px 30px;
            background: rgba(255,255,255,0.1);
            border-radius: 30px;
            transition: all 0.3s;
        }
        .file-type-selector input:checked + .radio-btn {
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            color: #1a1a2e;
            font-weight: 600;
        }
        .drop-zone {
            border: 2px dashed rgba(255,255,255,0.3);
            border-radius: 15px;
            padding: 50px;
            text-align: center;
            transition: all 0.3s;
            cursor: pointer;
        }
        .drop-zone:hover, .drop-zone.dragover {
            border-color: #4facfe;
            background: rgba(79,172,254,0.1);
        }
        .drop-icon { font-size: 3rem; display: block; margin-bottom: 15px; }
        .drop-zone p { color: #888; margin-bottom: 10px; }
        .hint { font-size: 0.85rem !important; color: #666 !important; }
        .or { color: #555; font-size: 0.9rem; }
        .browse-btn {
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            border: none;
            padding: 12px 30px;
            border-radius: 30px;
            color: #1a1a2e;
            font-weight: 600;
            cursor: pointer;
            margin-top: 10px;
            transition: transform 0.2s;
        }
        .browse-btn:hover { transform: scale(1.05); }
        .file-list {
            margin-top: 20px;
            background: rgba(0,0,0,0.3);
            border-radius: 10px;
            overflow: hidden;
        }
        .file-list-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px;
            background: rgba(0,0,0,0.2);
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .clear-btn {
            background: #ff4757;
            border: none;
            padding: 8px 16px;
            border-radius: 5px;
            color: white;
            cursor: pointer;
            font-size: 0.85rem;
        }
        .file-items { max-height: 200px; overflow-y: auto; padding: 10px; }
        .file-item {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 8px 12px;
            background: rgba(255,255,255,0.05);
            border-radius: 6px;
            margin-bottom: 6px;
            font-size: 0.9rem;
        }
        .file-item-icon { font-size: 1.2rem; }
        .file-item-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .file-item-size { color: #888; font-size: 0.8rem; }
        .benchmark-btn {
            width: 100%;
            padding: 18px;
            margin-top: 25px;
            background: linear-gradient(90deg, #f093fb, #f5576c);
            border: none;
            border-radius: 10px;
            color: white;
            font-size: 1.1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        .benchmark-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .progress-section {
            background: rgba(255,255,255,0.05);
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 30px;
        }
        .progress-header {
            display: flex;
            justify-content: space-between;
            margin-bottom: 15px;
        }
        .progress-bar {
            height: 8px;
            background: rgba(255,255,255,0.1);
            border-radius: 4px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            width: 0%;
            transition: width 0.3s;
        }
        .results {
            background: rgba(255,255,255,0.05);
            border-radius: 20px;
            padding: 30px;
        }
        .results h2 { text-align: center; margin-bottom: 25px; }
        .batch-summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 15px;
            margin-bottom: 25px;
        }
        .summary-card {
            background: rgba(0,0,0,0.2);
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .summary-card .value { font-size: 2rem; font-weight: 700; }
        .summary-card .label { font-size: 0.85rem; color: #888; margin-top: 5px; }
        .summary-card.dynamsoft .value { color: #2196F3; }
        .summary-card.mlkit .value { color: #4CAF50; }
        .summary-card.vision .value { color: #9C27B0; }
        .summary-card.zxingcpp .value { color: #FF9800; }
        .sdk-result.zxingcpp { border-top: 3px solid #FF9800; }
        .results-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 25px; }
        .results-header h2 { margin-bottom: 0; }
        .export-btn {
            background: linear-gradient(90deg, #4facfe, #00f2fe);
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            color: #1a1a2e;
            font-weight: 600;
            cursor: pointer;
            font-size: 0.95rem;
            transition: transform 0.2s;
        }
        .export-btn:hover { transform: scale(1.05); }
        .file-result {
            background: rgba(0,0,0,0.2);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .file-result h3 { margin-bottom: 15px; color: #4facfe; }
        .sdk-section { margin-bottom: 15px; }
        .sdk-section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 12px;
            border-radius: 6px;
            margin-bottom: 8px;
        }
        .sdk-section-header.dynamsoft { background: rgba(33,150,243,0.2); color: #2196F3; }
        .sdk-section-header.mlkit { background: rgba(76,175,80,0.2); color: #4CAF50; }
        .sdk-section-header.vision { background: rgba(156,39,176,0.2); color: #9C27B0; }
        .sdk-section-header.zxingcpp { background: rgba(255,152,0,0.2); color: #FF9800; }
        .barcode-item {
            padding: 6px 12px;
            background: rgba(255,255,255,0.05);
            border-radius: 4px;
            margin-bottom: 4px;
            font-size: 0.85rem;
            display: flex;
            gap: 10px;
        }
        .barcode-format {
            font-weight: 600;
            min-width: 100px;
        }
        .barcode-text {
            color: #ccc;
            word-break: break-all;
        }
        .comparison {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        .sdk-result {
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
            padding: 15px;
        }
        .sdk-result.dynamsoft { border-top: 3px solid #2196F3; }
        .sdk-result.mlkit { border-top: 3px solid #4CAF50; }
        .sdk-result.vision { border-top: 3px solid #9C27B0; }
        footer { text-align: center; margin-top: 40px; color: #555; font-size: 0.9rem; }
        .video-progress { margin-top: 16px; background: rgba(0,0,0,0.3); border-radius: 10px; padding: 14px 18px; }
        .vp-label { font-size: 0.95rem; font-weight: 600; color: #4facfe; margin-bottom: 4px; }
        .vp-frames { font-size: 0.85rem; color: #aaa; margin-bottom: 8px; }
        .vp-bar-wrap { height: 6px; background: rgba(255,255,255,0.1); border-radius: 3px; overflow: hidden; }
        .vp-bar-fill { height: 100%; background: linear-gradient(90deg, #4facfe, #00f2fe); width: 0%; transition: width 0.4s ease; border-radius: 3px; }
        """
    }
    
    // MARK: - JS Content
    private func getAppJs() -> String {
        return """
        const dropZone = document.getElementById('dropZone');
        const fileInput = document.getElementById('fileInput');
        const browseBtn = document.getElementById('browseBtn');
        const fileList = document.getElementById('fileList');
        const fileItems = document.getElementById('fileItems');
        const fileCount = document.getElementById('fileCount');
        const clearBtn = document.getElementById('clearBtn');
        const benchmarkBtn = document.getElementById('benchmarkBtn');
        const progressSection = document.getElementById('progressSection');
        const progressFill = document.getElementById('progressFill');
        const progressText = document.getElementById('progressText');
        const results = document.getElementById('results');
        const batchSummary = document.getElementById('batchSummary');
        
        const batchResults = document.getElementById('batchResults');
        const exportBtn = document.getElementById('exportBtn');
        
        let selectedFiles = [];
        let benchmarkResults = [];
        let showBenchmarkTime = true;
        
        // Fetch config
        fetch('/api/config').then(r => r.json()).then(cfg => { showBenchmarkTime = cfg.showBenchmarkTime; }).catch(() => {});
        
        dropZone.addEventListener('dragover', (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
        dropZone.addEventListener('dragleave', () => { dropZone.classList.remove('dragover'); });
        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.classList.remove('dragover');
            addFiles(Array.from(e.dataTransfer.files));
        });
        
        function addFiles(files) {
            files.forEach(file => {
                if (file.type.startsWith('image/') || file.type.startsWith('video/')) {
                    if (!selectedFiles.find(f => f.name === file.name)) {
                        selectedFiles.push(file);
                    }
                }
            });
            updateFileList();
        }
        
        function updateFileList() {
            if (selectedFiles.length === 0) {
                fileList.style.display = 'none';
                benchmarkBtn.disabled = true;
                return;
            }
            fileList.style.display = 'block';
            benchmarkBtn.disabled = false;
            fileCount.textContent = selectedFiles.length + ' file(s) selected';
            fileItems.innerHTML = selectedFiles.map((file, idx) => `
                <div class="file-item" data-idx="${idx}">
                    <span class="file-item-icon">${file.type.startsWith('video/') ? '🎬' : '🖼️'}</span>
                    <span class="file-item-name">${file.name}</span>
                    <span class="file-item-size">${(file.size/1024/1024).toFixed(1)} MB</span>
                </div>
            `).join('');
        }
        
        dropZone.addEventListener('click', () => fileInput.click());
        browseBtn.addEventListener('click', (e) => { e.stopPropagation(); fileInput.click(); });
        fileInput.addEventListener('change', (e) => { addFiles(Array.from(e.target.files)); fileInput.value = ''; });
        clearBtn.addEventListener('click', () => { selectedFiles = []; updateFileList(); results.style.display = 'none'; });
        
        // Reset all UI state when switching between image and video modes
        document.querySelectorAll('input[name="fileType"]').forEach(radio => {
            radio.addEventListener('change', () => {
                selectedFiles = [];
                benchmarkResults = [];
                updateFileList();
                results.style.display = 'none';
                progressSection.style.display = 'none';
                progressFill.style.width = '0%';
                progressText.textContent = 'Processing...';
                document.getElementById('currentFile').textContent = '';
                stopVideoProgressPolling();
                hideVideoPreview();
            });
        });
        
        // Video preview helper: show <video> for a video file
        const videoPreviewBox = document.getElementById('videoPreviewBox');
        const videoPlayer     = document.getElementById('videoPlayer');
        const videoProgress   = document.getElementById('videoProgress');
        const vpLabel         = document.getElementById('vpLabel');
        const vpFrames        = document.getElementById('vpFrames');
        const vpBarFill       = document.getElementById('vpBarFill');
        let videoPollTimer    = null;
        let videoObjectURL    = null;
        let benchmarkInProgress = false;

        function showVideoPreview(file) {
            if (videoObjectURL) { URL.revokeObjectURL(videoObjectURL); videoObjectURL = null; }
            videoObjectURL = URL.createObjectURL(file);
            videoPlayer.src = videoObjectURL;
            videoPreviewBox.style.display = 'block';
        }
        function hideVideoPreview() {
            videoPreviewBox.style.display = 'none';
            videoPlayer.src = '';
            if (videoObjectURL) { URL.revokeObjectURL(videoObjectURL); videoObjectURL = null; }
        }
        function startVideoProgressPolling() {
            videoProgress.style.display = 'block';
            videoPollTimer = setInterval(async () => {
                try {
                    const r = await fetch('/api/video-progress');
                    const p = await r.json();
                    // Only auto-stop when benchmark has fully completed, not during file upload
                    if (!p.isActive) {
                        if (!benchmarkInProgress) { stopVideoProgressPolling(); }
                        return;
                    }
                    vpLabel.textContent = '⚙️ ' + p.sdk;
                    vpFrames.textContent = 'Frame ' + p.frame + ' / ' + p.total + '  (' + (p.completedSDKs) + '/4 SDKs done)';
                    vpBarFill.style.width = p.percent + '%';
                } catch (_) {}
            }, 350);
        }
        function stopVideoProgressPolling() {
            if (videoPollTimer) { clearInterval(videoPollTimer); videoPollTimer = null; }
            videoProgress.style.display = 'none';
            vpBarFill.style.width = '0%';
        }

        benchmarkBtn.addEventListener('click', async () => {
            if (selectedFiles.length === 0) return;
            progressSection.style.display = 'block';
            results.style.display = 'none';
            benchmarkBtn.disabled = true;
            benchmarkResults = [];
            hideVideoPreview();
            stopVideoProgressPolling();
            benchmarkInProgress = true;
            
            for (let i = 0; i < selectedFiles.length; i++) {
                const file = selectedFiles[i];
                const isVideo = file.type.startsWith('video/');
                progressFill.style.width = ((i / selectedFiles.length) * 100) + '%';
                progressText.textContent = `${i + 1} / ${selectedFiles.length}`;
                document.getElementById('currentFile').textContent = file.name;

                if (isVideo) {
                    showVideoPreview(file);
                    startVideoProgressPolling();
                } else {
                    hideVideoPreview();
                    stopVideoProgressPolling();
                }

                const formData = new FormData();
                formData.append('file', file);
                formData.append('fileType', isVideo ? 'video' : 'image');
                
                try {
                    const response = await fetch('/api/benchmark', { method: 'POST', body: formData });
                    const data = await response.json();
                    data.fileName = file.name;
                    benchmarkResults.push(data);
                } catch (error) {
                    benchmarkResults.push({ fileName: file.name, error: error.message });
                }
                stopVideoProgressPolling();
            }
            benchmarkInProgress = false;
            
            hideVideoPreview();
            progressFill.style.width = '100%';
            progressText.textContent = 'Complete!';
            document.getElementById('currentFile').textContent = '';
            benchmarkBtn.disabled = false;
            displayResults();
        });
        
        function displayResults() {
            results.style.display = 'block';
            let totalDynamsoft = 0, totalMlkit = 0, totalVision = 0, totalZxingcpp = 0;
            let totalDynamsoftTime = 0, totalMlkitTime = 0, totalVisionTime = 0, totalZxingcppTime = 0;
            
            benchmarkResults.forEach(r => {
                if (!r.error) {
                    totalDynamsoft += r.dynamsoft?.count || 0;
                    totalMlkit += r.mlkit?.count || 0;
                    totalVision += r.vision?.count || 0;
                    totalZxingcpp += r.zxingcpp?.count || 0;
                    totalDynamsoftTime += r.dynamsoft?.timeMs || 0;
                    totalMlkitTime += r.mlkit?.timeMs || 0;
                    totalVisionTime += r.vision?.timeMs || 0;
                    totalZxingcppTime += r.zxingcpp?.timeMs || 0;
                }
            });
            
            batchSummary.innerHTML = `
                <div class="summary-card"><div class="value">${benchmarkResults.length}</div><div class="label">Files</div></div>
                <div class="summary-card dynamsoft"><div class="value">${totalDynamsoft}</div><div class="label">Dynamsoft</div></div>
                <div class="summary-card mlkit"><div class="value">${totalMlkit}</div><div class="label">MLKit</div></div>
                <div class="summary-card vision"><div class="value">${totalVision}</div><div class="label">Vision</div></div>
                <div class="summary-card zxingcpp"><div class="value">${totalZxingcpp}</div><div class="label">ZXing-CPP</div></div>
            `;
            
            let detailsHtml = '';
            benchmarkResults.forEach((r, idx) => {
                if (r.error) {
                    detailsHtml += `<div class="file-result"><h3>${r.fileName}</h3><p style="color:#ff4757">Error: ${r.error}</p></div>`;
                    return;
                }
                const sdks = [
                    { key: 'dynamsoft', name: 'Dynamsoft', cls: 'dynamsoft' },
                    { key: 'mlkit', name: 'MLKit', cls: 'mlkit' },
                    { key: 'vision', name: 'Apple Vision', cls: 'vision' },
                    { key: 'zxingcpp', name: 'ZXing-CPP', cls: 'zxingcpp' }
                ];
                let sdkHtml = '';
                sdks.forEach(sdk => {
                    const d = r[sdk.key];
                    if (!d) return;
                    const timeStr = showBenchmarkTime ? ` — ${d.timeMs} ms` : '';
                    let barcodesHtml = '';
                    if (d.barcodes && d.barcodes.length > 0) {
                        barcodesHtml = d.barcodes.map(b => `<div class="barcode-item"><span class="barcode-format">${b.format}</span><span class="barcode-text">${escapeHtml(b.text)}</span></div>`).join('');
                    } else {
                        barcodesHtml = '<div class="barcode-item" style="color:#888;font-style:italic">No barcodes detected</div>';
                    }
                    sdkHtml += `<div class="sdk-section"><div class="sdk-section-header ${sdk.cls}"><span>${sdk.name}: ${d.count} barcode(s)${timeStr}</span></div>${barcodesHtml}</div>`;
                });
                detailsHtml += `<div class="file-result"><h3>📄 ${r.fileName}</h3>${sdkHtml}</div>`;
            });
            batchResults.innerHTML = detailsHtml;
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        exportBtn.addEventListener('click', () => {
            const date = new Date().toISOString().slice(0, 10);
            const sdkList = [
                { key: 'dynamsoft', name: 'Dynamsoft', color: '#2196F3' },
                { key: 'mlkit', name: 'MLKit', color: '#4CAF50' },
                { key: 'vision', name: 'Apple Vision', color: '#9C27B0' },
                { key: 'zxingcpp', name: 'ZXing-CPP', color: '#FF9800' }
            ];
            
            let tableRows = '';
            benchmarkResults.forEach(r => {
                if (r.error) {
                    tableRows += `<tr><td style="padding:10px 14px;border-bottom:1px solid #333;">${escapeHtml(r.fileName)}</td><td colspan="4" style="padding:10px 14px;border-bottom:1px solid #333;color:#ff4757">Error: ${escapeHtml(r.error)}</td></tr>`;
                    return;
                }
                let sdkCells = sdkList.map(sdk => {
                    const d = r[sdk.key];
                    if (!d) return '<td style="padding:10px 14px;border-bottom:1px solid #333;">—</td>';
                    const barcodeList = d.barcodes && d.barcodes.length > 0
                        ? d.barcodes.map(b => `<div style="margin:2px 0;"><span style="background:${sdk.color}22;color:${sdk.color};font-size:11px;padding:1px 5px;border-radius:3px;margin-right:4px;">${escapeHtml(b.format)}</span>${escapeHtml(b.text)}</div>`).join('')
                        : '<span style="color:#666;font-style:italic">No barcodes</span>';
                    return `<td style="padding:10px 14px;border-bottom:1px solid #333;vertical-align:top;"><div style="font-weight:600;color:${sdk.color};margin-bottom:4px;">${d.count} barcode(s) — ${d.timeMs} ms</div>${barcodeList}</td>`;
                }).join('');
                tableRows += `<tr><td style="padding:10px 14px;border-bottom:1px solid #333;vertical-align:top;font-size:13px;">${escapeHtml(r.fileName)}</td>${sdkCells}</tr>`;
            });
            
            const headerCells = sdkList.map(sdk => `<th style="padding:12px 14px;text-align:left;background:#1a1a2e;color:${sdk.color};">${sdk.name}</th>`).join('');
            
            // Aggregate totals for bar charts
            const totals = sdkList.map(sdk => {
                let count = 0, time = 0;
                benchmarkResults.forEach(r => { if (!r.error && r[sdk.key]) { count += r[sdk.key].count; time += r[sdk.key].timeMs; } });
                return { ...sdk, count, time };
            });
            const maxCount = Math.max(...totals.map(s => s.count), 1);
            const maxTime  = Math.max(...totals.map(s => s.time), 1);
            
            function barRow(label, value, max, color, unit) {
                const pct = Math.min((value / max) * 100, 100).toFixed(1);
                return '<tr><td style="padding:6px 14px;color:#aaa;font-size:13px;white-space:nowrap;width:120px;">' + label + '</td>' +
                    '<td style="padding:6px 14px;"><div style="background:rgba(255,255,255,0.08);border-radius:4px;overflow:hidden;height:20px;">' +
                    '<div style="background:' + color + ';height:100%;width:' + pct + '%;border-radius:4px;transition:width 0.5s;"></div></div></td>' +
                    '<td style="padding:6px 14px;color:' + color + ';font-weight:600;font-size:13px;white-space:nowrap;">' + value + ' ' + unit + '</td></tr>';
            }
            const countBars = totals.map(s => barRow(s.name, s.count, maxCount, s.color, 'barcodes')).join('');
            const timeBars  = totals.map(s => barRow(s.name, s.time,  maxTime,  s.color, 'ms')).join('');
            const chartSection = [
                '<div style="display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:32px;">',
                '<div style="background:rgba(255,255,255,0.04);border-radius:12px;padding:20px;">',
                '<h2 style="font-size:1rem;font-weight:600;color:#4facfe;margin-bottom:14px;">Barcodes Detected (total)</h2>',
                '<table style="width:100%;border-collapse:collapse;background:none;box-shadow:none;">' + countBars + '</table></div>',
                '<div style="background:rgba(255,255,255,0.04);border-radius:12px;padding:20px;">',
                '<h2 style="font-size:1rem;font-weight:600;color:#4facfe;margin-bottom:14px;">Processing Time (total ms)</h2>',
                '<table style="width:100%;border-collapse:collapse;background:none;box-shadow:none;">' + timeBars + '</table></div>',
                '</div>'
            ].join('');
            
            const htmlParts = [
                '<!DOCTYPE html><html lang="en"><head>',
                '<meta charset="UTF-8">',
                '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
                '<title>Barcode Benchmark Report - ' + date + '</title>',
                '<style>',
                'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#0f0f1a;color:#e0e0e0;margin:0;padding:32px;}',
                'h1{font-size:1.8rem;margin-bottom:4px;color:#4facfe;}',
                'p.subtitle{color:#888;margin-bottom:28px;}',
                'table{width:100%;border-collapse:collapse;background:rgba(255,255,255,0.04);border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.4);}',
                'th{font-size:14px;font-weight:600;}',
                'td{font-size:13px;color:#ccc;max-width:300px;word-break:break-word;}',
                'tr:hover td{background:rgba(255,255,255,0.03);}',
                '</style></head><body>',
                '<h1>Barcode Benchmark Report</h1>',
                '<p class="subtitle">Generated: ' + date + ' &nbsp;|&nbsp; ' + benchmarkResults.length + ' file(s)</p>',
                chartSection,
                '<h2 style="font-size:1.1rem;font-weight:600;color:#4facfe;margin-bottom:16px;">Per-File Results</h2>',
                '<table><thead><tr><th style="padding:12px 14px;text-align:left;background:#1a1a2e;color:#aaa;">File</th>' + headerCells + '</tr></thead>',
                '<tbody>' + tableRows + '</tbody></table>',
                '</body></html>'
            ];
            const html = htmlParts.join('\\n');            
            const blob = new Blob([html], { type: 'text/html' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'benchmark_report_' + date + '.html';
            a.click();
            URL.revokeObjectURL(url);
        });
        """
    }
}

enum ServerError: Error {
    case invalidPort
    case notInitialized
    case socketError
}
