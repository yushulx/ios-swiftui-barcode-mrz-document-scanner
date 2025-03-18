import SwiftUI

struct ScannerType {
    static let TWAINSCANNER: Int = 0x10
    static let WIASCANNER: Int = 0x20
    static let TWAINX64SCANNER: Int = 0x40
    static let ICASCANNER: Int = 0x80
    static let SANESCANNER: Int = 0x100
    static let ESCLSCANNER: Int = 0x200
    static let WIFIDIRECTSCANNER: Int = 0x400
    static let WIATWAINSCANNER: Int = 0x800
}

class ScannerController {
    static let SCAN_SUCCESS = "success"
    static let SCAN_ERROR = "error"

    private let httpClient = URLSession.shared

    /// Get a list of available devices.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - scannerType: The type of scanner. Defaults to nil.
    /// - Returns: A list of available devices.
    func getDevices(host: String, scannerType: Int? = nil) async -> [[String: Any]] {
        var devices: [[String: Any]] = []

        do {
            let response = try await getDevicesHttpResponse(host: host, scannerType: scannerType)
            if response.statusCode == 200 {
                if let data = response.data, let responseBody = String(data: data, encoding: .utf8),
                    !responseBody.isEmpty
                {
                    devices = try JSONDecoder().decode([[String: AnyCodable]].self, from: data).map
                    { $0.mapValues { $0.value } }
                }
            }
        } catch {
            print(error.localizedDescription)
        }

        return devices
    }

    /// Get a list of available devices and return the HTTP response.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - scannerType: The type of scanner. Defaults to nil.
    /// - Returns: HTTP response.
    func getDevicesHttpResponse(host: String, scannerType: Int? = nil) async throws -> (
        statusCode: Int, data: Data?
    ) {
        var url = URL(string: "\(host)/DWTAPI/Scanners")!
        if let scannerType = scannerType {
            url = URL(string: "\(host)/DWTAPI/Scanners?type=\(scannerType)")!
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }
        return (httpResponse.statusCode, data)
    }

    /// Scan a document.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - parameters: The parameters for the scan.
    /// - Returns: A dictionary containing the job ID or an error message.
    func scanDocument(host: String, parameters: [String: Any]) async -> [String: String] {
        var dict: [String: String] = [:]

        do {
            let response = try await scanDocumentHttpResponse(host: host, parameters: parameters)
            if let data = response.data, let text = String(data: data, encoding: .utf8) {
                if response.statusCode == 200 || response.statusCode == 201 {
                    dict[ScannerController.SCAN_SUCCESS] = text
                } else {
                    dict[ScannerController.SCAN_ERROR] = text
                }
            }
        } catch {
            dict[ScannerController.SCAN_ERROR] = error.localizedDescription
        }

        return dict
    }

    /// Scan a document and return the HTTP response.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - parameters: The parameters for the scan.
    /// - Returns: HTTP response.
    func scanDocumentHttpResponse(host: String, parameters: [String: Any]) async throws -> (
        statusCode: Int, data: Data?
    ) {
        let url = URL(string: "\(host)/DWTAPI/ScanJobs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }
        return (httpResponse.statusCode, data)
    }

    /// Delete a job and return the HTTP response.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - jobId: The ID of the job.
    /// - Returns: HTTP response.
    func deleteJob(host: String, jobId: String) async throws -> (statusCode: Int, data: Data?) {
        let url = URL(string: "\(host)/DWTAPI/ScanJobs/\(jobId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }
        return (httpResponse.statusCode, data)
    }

    /// Get an image file.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - jobId: The ID of the job.
    ///   - directory: The directory to save the image file.
    /// - Returns: The image file path.
    func getImageFile(host: String, jobId: String, directory: String) async -> String {
        do {
            let response = try await getImageStreamHttpResponse(host: host, jobId: jobId)
            if response.statusCode == 200, let data = response.data {
                let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                let filename = "image_\(timestamp).jpg"
                let imagePath = URL(fileURLWithPath: directory).appendingPathComponent(filename)
                    .path
                try data.write(to: URL(fileURLWithPath: imagePath))
                return filename
            }
        } catch {
            print("No more images.")
        }

        return ""
    }

    /// Get a list of image files.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - jobId: The ID of the job.
    ///   - directory: The directory to save the image files.
    /// - Returns: A list of image file paths.
    func getImageFiles(host: String, jobId: String, directory: String) async -> [String] {
        var images: [String] = []

        while true {
            let filename = await getImageFile(host: host, jobId: jobId, directory: directory)
            if filename.isEmpty {
                break
            } else {
                images.append(filename)
            }
        }

        return images
    }

    /// Get a list of image streams.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - jobId: The ID of the job.
    /// - Returns: A list of image streams.
    func getImageStreams(host: String, jobId: String) async -> [[UInt8]] {
        var streams: [[UInt8]] = []

        while true {
            let bytes = await getImageStream(host: host, jobId: jobId)
            if bytes.isEmpty {
                break
            } else {
                streams.append(bytes)
            }
        }

        return streams
    }

    /// Get an image stream.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - jobId: The ID of the job.
    /// - Returns: An image stream.
    func getImageStream(host: String, jobId: String) async -> [UInt8] {
        do {
            let response = try await getImageStreamHttpResponse(host: host, jobId: jobId)

            if response.statusCode == 200, let data = response.data {
                return Array(data)
            } else if response.statusCode == 410 {
                return []
            }
        } catch {
            return []
        }

        return []
    }

    /// Get an image stream and return the HTTP response.
    /// - Parameters:
    ///   - host: The URL of the Dynamsoft Service API.
    ///   - jobId: The ID of the job.
    /// - Returns: HTTP response.
    func getImageStreamHttpResponse(host: String, jobId: String) async throws -> (
        statusCode: Int, data: Data?
    ) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let url = URL(string: "\(host)/DWTAPI/ScanJobs/\(jobId)/NextDocument?\(timestamp)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }
        return (httpResponse.statusCode, data)
    }
}

// Helper struct for decoding dynamic JSON objects
struct AnyCodable: Codable {
    let value: Any

    init<T: Codable>(_ value: T) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictionaryValue = try? container.decode([String: AnyCodable].self) {
            value = dictionaryValue.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [AnyCodable]:
            try container.encode(arrayValue)
        case let dictionaryValue as [String: AnyCodable]:
            try container.encode(dictionaryValue)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
