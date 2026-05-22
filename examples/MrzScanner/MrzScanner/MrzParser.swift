//
//  MrzParser.swift
//  MrzScanner
//
//  Ported from Android IdScanner MrzParser.java
//

import Foundation
import DynamsoftCaptureVisionBundle

struct MrzParser {

    private static let licenseKey = "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ=="

    static func initLicense() {
        LicenseManager.initLicense(licenseKey, verificationDelegate: nil)
    }

    /// Parse a ParsedResultItem from Dynamsoft Capture Vision and return a label map
    /// mirroring the Android MrzParser.parse(ParsedResultItem) output.
    static func parse(_ item: ParsedResultItem) -> [String: String] {
        let entry = item.parsedFields
        var properties: [String: String] = [:]

        // Determine document type from codeType
        let codeType = item.codeType
        var docType = "PASSPORT"
        if codeType.contains("TD1") || codeType.contains("ID") {
            docType = "ID"
        } else if codeType.contains("VISA") {
            docType = "VISA"
        }

        // Extract fields with priority fallback (mirrors Android getFirstNonNull)
        let number = getFirstNonNull(entry, keys: ["passportNumber", "documentNumber", "idNumber"])
        let firstName = getFirstNonNull(entry, keys: ["secondaryIdentifier", "givenNames"])
        let lastName = getFirstNonNull(entry, keys: ["primaryIdentifier", "lastName"])
        let nationality = entry["nationality"] ?? "Unknown"
        let issuingState = entry["issuingState"] ?? "Unknown"
        let sex = entry["sex"] ?? "Unknown"

        // Format Name: "LastName, FirstName"
        var fullName = lastName
        if !firstName.isEmpty {
            if !fullName.isEmpty {
                fullName += ", "
            }
            fullName += firstName
        }
        if fullName.isEmpty {
            fullName = "—"
        }

        // Calculate age
        var age = -1
        if let birthYearStr = entry["birthYear"],
           let birthMonthStr = entry["birthMonth"],
           let birthDayStr = entry["birthDay"],
           let year = Int(birthYearStr),
           let month = Int(birthMonthStr),
           let day = Int(birthDayStr) {
            age = calculateAge(birthYear: year, birthMonth: month, birthDay: day)
        }

        // Format Dates
        let birthDate = formatDate(year: entry["birthYear"], month: entry["birthMonth"], day: entry["birthDay"])
        let expiryDate = formatDate(year: entry["expiryYear"], month: entry["expiryMonth"], day: entry["expiryDay"])

        properties["Document Type"] = docType
        properties["Name"] = fullName
        properties["Sex"] = formatSex(sex)
        properties["Age"] = age >= 0 ? String(age) : "—"
        properties["Document Number"] = number.isEmpty ? "—" : number
        properties["Issuing State"] = issuingState
        properties["Nationality"] = nationality
        properties["Date of Birth(YYYY-MM-DD)"] = birthDate.isEmpty ? "—" : birthDate
        properties["Date of Expiry(YYYY-MM-DD)"] = expiryDate.isEmpty ? "—" : expiryDate

        return properties
    }

    // MARK: - Helpers

    private static func getFirstNonNull(_ map: [String: String], keys: [String]) -> String {
        for key in keys {
            if let value = map[key], !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private static func formatSex(_ sex: String) -> String {
        guard !sex.isEmpty else { return "—" }
        switch sex.uppercased().first {
        case "M": return "MALE"
        case "F": return "FEMALE"
        default: return sex
        }
    }

    private static func formatDate(year: String?, month: String?, day: String?) -> String {
        guard let year = year, let month = month, let day = day else { return "" }
        return "\(year)-\(month)-\(day)"
    }

    private static func calculateAge(birthYear: Int, birthMonth: Int, birthDay: Int) -> Int {
        var dob = DateComponents()
        dob.year = birthYear
        dob.month = birthMonth
        dob.day = birthDay

        let calendar = Calendar.current
        guard let birthDate = calendar.date(from: dob) else { return -1 }

        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year ?? -1
    }
}
