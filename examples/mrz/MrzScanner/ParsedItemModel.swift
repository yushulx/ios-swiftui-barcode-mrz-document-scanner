import Foundation
import DynamsoftCodeParser

class ParsedItemModel {
    var documentType: String! = ""
    var name: String! = ""
    var gender: String! = ""
    var age: Int! = 0
    var documentNumber: String! = ""
    var issuingState: String! = ""
    var nationality: String! = ""
    var dateOfBirth: String! = ""
    var dateOfExpiry: String! = ""
    
    func isLegalMRZ(_ parsedItem: ParsedResultItem) -> Bool {
        let parsedFields = parsedItem.parsedFields
        let documentType = parsedItem.codeType
        var isLegal = true
        if parsedFields["birthDay"] == nil ||
            parsedFields["birthMonth"] == nil ||
            parsedFields["birthYear"] == nil ||
            parsedFields["expiryDay"] == nil ||
            parsedFields["expiryMonth"] == nil ||
            parsedFields["expiryYear"] == nil ||
            parsedFields["sex"] == nil ||
            parsedFields["issuingState"] == nil ||
            parsedFields["nationality"] == nil ||
            parsedFields["primaryIdentifier"] == nil ||
            parsedFields["secondaryIdentifier"] == nil {
            isLegal = false
        }
        
        let birthDay = parsedFields["birthDay"] ?? ""
        let birthMonth = parsedFields["birthMonth"] ?? ""
        var birthYear = "-1"
        if let year = Int(parsedFields["birthYear"] ?? "")  {
            let currentYear = Calendar.current.component(.year, from: Date())
            if year > (currentYear - 2000) {
                birthYear = String(1900 + year)
            } else {
                birthYear = String(2000 + year)
            }
        }
        let expiryDay = parsedFields["expiryDay"] ?? "--"
        let expiryMonth = parsedFields["expiryMonth"] ?? "--"
        var expiryYear = "----"
        if let year = parsedFields["expiryYear"], let yearValue = Int(year) {
            expiryYear = String(2000 + yearValue)
        }
        self.gender = parsedFields["sex"]?.capitalized ?? ""
        if let year = Int(birthYear), let month = Int(birthMonth), let day = Int(birthDay) {
            let birthdayComponents = DateComponents(calendar: Calendar.current, year: year, month: month, day: day)
            if let birthdayDate = birthdayComponents.date {
                let currentDate = Date()
                let calendar = Calendar.current
                let ageComponents = calendar.dateComponents([.year, .month, .day], from: birthdayDate, to: currentDate)
                self.age = ageComponents.year
            }
        }
        self.issuingState = parsedFields["issuingState"] ?? ""
        self.nationality = parsedFields["nationality"] ?? ""
        self.dateOfBirth = birthYear + "-" + birthMonth + "-" + birthDay
        self.dateOfExpiry = expiryYear + "-" + expiryMonth + "-" + expiryDay
        
        switch documentType {
        case "MRTD_TD1_ID", "MRTD_TD2_ID":
            self.name = parsedFields["name"] ?? ""
            self.documentNumber = parsedFields["documentNumber"] ?? ""
            self.documentType = "ID"
            break
        case "MRTD_TD3_PASSPORT":
            let primaryIdentifier = parsedFields["primaryIdentifier"] ?? ""
            let secondaryIdentifier = parsedFields["secondaryIdentifier"] ?? ""
            if primaryIdentifier != "" && secondaryIdentifier != "" {
                self.name = secondaryIdentifier + " " + primaryIdentifier
            } else if primaryIdentifier != "" && secondaryIdentifier == "" {
                self.name = primaryIdentifier
            } else if primaryIdentifier == "" && secondaryIdentifier != "" {
                self.name = secondaryIdentifier
            } else {
                self.name = ""
            }
            self.documentNumber = parsedFields["passportNumber"] ?? ""
            self.documentType = "Passport"
            break
        default:
            self.documentNumber = ""
            self.name = ""
            self.documentType = ""
        }
        
        if self.name == "" ||  self.documentNumber == "" ||  self.documentType == "" {
            isLegal = false
        }
        
        return isLegal
    }
    
    func isLegalDriverLicense(_ parsedItem: ParsedResultItem) -> Bool {
        let allKeys = parsedItem.parsedFields.keys
        var isLegal = false
        switch parsedItem.codeType {
        case DriverLicenseType.AAMVA_DL_ID.rawValue:
            if (allKeys.contains("lastName") ||
                allKeys.contains("givenName") ||
                allKeys.contains("firstName") ||
                allKeys.contains("fullName")) &&
                allKeys.contains("licenseNumber") {
                isLegal = true
            }
            break
        case DriverLicenseType.AAMVA_DL_ID_WITH_MAG_STRIPE.rawValue:
            if  allKeys.contains("name") &&
                allKeys.contains("DLorID_Number") {
                isLegal = true
            }
            break
        case DriverLicenseType.SOUTH_AFRICA_DL.rawValue:
            if  allKeys.contains("surname") &&
                allKeys.contains("idNumber") {
                isLegal = true
            }
            break
        default:
            break
        }
        return isLegal
    }
}

enum DriverLicenseType: String {
    case AAMVA_DL_ID = "AAMVA_DL_ID"
    case AAMVA_DL_ID_WITH_MAG_STRIPE = "AAMVA_DL_ID_WITH_MAG_STRIPE"
    case SOUTH_AFRICA_DL = "SOUTH_AFRICA_DL"
}

let AAMVA_DL_ID_InfoList: [[String: String]] = [["Title": "Last Name", "FieldName": "lastName"],
                                                ["Title": "Given Name", "FieldName": "givenName"],
                                                ["Title": "First Name", "FieldName": "firstName"],
                                                ["Title": "Full Name", "FieldName": "fullName"],
                                                ["Title": "Street", "FieldName": "street_1", "FieldName2": "street_2"],
                                                ["Title": "City", "FieldName": "city"],
                                                ["Title": "State", "FieldName": "jurisdictionCode"],
                                                ["Title": "License Number", "FieldName": "licenseNumber"],
                                                ["Title": "Issue Date", "FieldName": "issuedDate"],
                                                ["Title": "Expiration Date", "FieldName": "expirationDate"],
                                                ["Title": "Date of Birth", "FieldName": "birthDate"],
                                                ["Title": "Height", "FieldName": "height"],
                                                ["Title": "Sex", "FieldName": "sex"],
                                                ["Title": "Issued Country", "FieldName": "issuingCountry"],
                                                ["Title": "Vehicle Class", "FieldName": "vehicleClass"]
]

let AAMVA_DL_ID_WITH_MAG_STRIPE_InfoList :[[String:String]] = [["Title":"Full Name", "FieldName":"name"],
                                                               ["Title":"Address", "FieldName":"address"],
                                                               ["Title":"City", "FieldName":"city"],
                                                               ["Title":"State or Province", "FieldName":"stateOrProvince"],
                                                               ["Title":"License Number", "FieldName":"DLorID_Number"],
                                                               ["Title":"Expiration Date", "FieldName":"expirationDate"],
                                                               ["Title":"Date of Birth", "FieldName":"birthDate"],
                                                               ["Title":"Height", "FieldName":"height"],
                                                               ["Title":"Sex", "FieldName":"sex"]
]

let SOUTH_AFRICA_DL_InfoList: [[String: String]] = [["Title": "Surname", "FieldName": "surname"],
                                                    ["Title": "ID Number", "FieldName": "idNumber"],
                                                    ["Title": "ID Number Type", "FieldName": "idNumberType"],
                                                    ["Title": "Initials", "FieldName": "initials"],
                                                    ["Title": "License Issue Number", "FieldName": "licenseIssueNumber"],
                                                    ["Title": "License Number", "FieldName": "licenseNumber"],
                                                    ["Title": "Validity from", "FieldName": "licenseValidityFrom"],
                                                    ["Title": "Validity to", "FieldName": "licenseValidityTo"],
                                                    ["Title": "Date of Birth", "FieldName": "birthDate"],
                                                    ["Title": "Gender", "FieldName": "gender"],
                                                    ["Title": "ID Issued Country", "FieldName": "idIssuedCountry"],
                                                    ["Title": "Driver Restriction Codes", "FieldName": "driverRestrictionCodes"]
]
