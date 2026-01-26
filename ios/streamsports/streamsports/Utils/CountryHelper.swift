import Foundation

class CountryHelper {
    static func name(for code: String) -> String? {
        let identifier = Locale(identifier: "en_US") // Force English for consistency or use .current
        return identifier.localizedString(forRegionCode: code)
    }
    
    static func flag(for code: String) -> String {
        let base = 127397
        var usv = String.UnicodeScalarView()
        for i in code.utf16 {
            usv.append(UnicodeScalar(base + Int(i))!)
        }
        return String(usv)
    }
}
