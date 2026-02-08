import Foundation

/// Direct stream resolver for cdn-live.tv
/// Ports the JavaScript decoding logic from Sports99Client.ts to Swift
/// This allows iOS to resolve streams directly, avoiding IP binding issues with proxies
class StreamResolver {
    
    static let shared = StreamResolver()
    
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1"
    private let referer = "https://streamsports99.su/"
    
    // MARK: - Public API
    
    /// Resolves a player URL to get the actual M3U8 stream URL
    /// - Parameters:
    ///   - playerUrl: The cdn-live.tv player URL (e.g., https://cdn-live.tv/api/v1/channels/player/?name=abc&code=us...)
    ///   - completion: Callback with (streamUrl, cookie) or (nil, nil) on failure
    func resolve(playerUrl: String, completion: @escaping (String?, String?) -> Void) {
        guard let url = URL(string: playerUrl) else {
            print("[StreamResolver] Invalid player URL")
            completion(nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard let data = data, let html = String(data: data, encoding: .utf8), error == nil else {
                print("[StreamResolver] Failed to fetch player page: \(error?.localizedDescription ?? "Unknown")")
                completion(nil, nil)
                return
            }
            
            // Extract cookie from response
            var cookie: String?
            if let httpResponse = response as? HTTPURLResponse,
               let setCookie = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                // Extract just the session cookie name=value
                cookie = setCookie.components(separatedBy: ";").first
            }
            
            // Decode the obfuscated JavaScript
            guard let decodedJs = self.decodeObfuscatedJs(html: html) else {
                print("[StreamResolver] Failed to decode obfuscated JS")
                completion(nil, nil)
                return
            }
            
            // Find the stream URL
            guard let streamUrl = self.findStreamUrl(jsCode: decodedJs) else {
                print("[StreamResolver] Failed to find stream URL in decoded JS")
                completion(nil, nil)
                return
            }
            
            print("[StreamResolver] ✅ Resolved: \(streamUrl.prefix(80))...")
            completion(streamUrl, cookie)
            
        }.resume()
    }
    
    // MARK: - Private Decoding Logic
    
    /// Converts a string from a custom base to decimal
    private func convertBase(_ s: String, base: Int) -> Int {
        var result = 0
        let reversed = Array(s.reversed())
        for (i, char) in reversed.enumerated() {
            if let digit = Int(String(char)) {
                result += digit * Int(pow(Double(base), Double(i)))
            }
        }
        return result
    }
    
    /// Decodes the obfuscated JavaScript from the player page
    private func decodeObfuscatedJs(html: String) -> String? {
        // Find the start marker: }("
        let startMarker = "}(\""
        guard let startRange = html.range(of: startMarker) else {
            print("[StreamResolver] Start marker not found")
            return nil
        }
        
        let actualStart = startRange.upperBound
        
        // Find the end marker: ",
        guard let endRange = html.range(of: "\",", range: actualStart..<html.endIndex) else {
            print("[StreamResolver] End marker not found")
            return nil
        }
        
        let encoded = String(html[actualStart..<endRange.lowerBound])
        
        // Extract parameters after the encoded string
        let paramsStart = endRange.upperBound
        let paramsEnd = html.index(paramsStart, offsetBy: min(100, html.distance(from: paramsStart, to: html.endIndex)))
        let params = String(html[paramsStart..<paramsEnd])
        
        // Match: digits, "charset", offset, base, extra
        // Pattern: (\d+),\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*(\d+)
        let pattern = #"(\d+),\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: params, range: NSRange(params.startIndex..., in: params)) else {
            print("[StreamResolver] Parameters not found")
            return nil
        }
        
        guard let charsetRange = Range(match.range(at: 2), in: params),
              let offsetRange = Range(match.range(at: 3), in: params),
              let baseRange = Range(match.range(at: 4), in: params) else {
            return nil
        }
        
        let charset = String(params[charsetRange])
        guard let offset = Int(params[offsetRange]),
              let base = Int(params[baseRange]) else {
            return nil
        }
        
        // Split by charset[base] character (the delimiter)
        guard base < charset.count else { return nil }
        let delimiterIndex = charset.index(charset.startIndex, offsetBy: base)
        let delimiter = String(charset[delimiterIndex])
        
        let parts = encoded.components(separatedBy: delimiter)
        
        var decoded = ""
        for part in parts where !part.isEmpty {
            var temp = part
            // Replace each charset character with its index
            for (idx, char) in charset.enumerated() {
                temp = temp.replacingOccurrences(of: String(char), with: String(idx))
            }
            let val = convertBase(temp, base: base)
            if val > offset, let scalar = UnicodeScalar(val - offset) {
                decoded += String(Character(scalar))
            }
        }
        
        // Try to URL decode
        return decoded.removingPercentEncoding ?? decoded
    }
    
    /// Finds the M3U8 stream URL in the decoded JavaScript
    private func findStreamUrl(jsCode: String) -> String? {
        // First try legacy pattern: direct m3u8 URL in quotes
        let legacyPattern = #"["']([^"']*index\.m3u8\?token=[^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: legacyPattern),
           let match = regex.firstMatch(in: jsCode, range: NSRange(jsCode.startIndex..., in: jsCode)),
           let range = Range(match.range(at: 1), in: jsCode) {
            return String(jsCode[range])
        }
        
        // New pattern: Base64 encoded URL fragments in variables
        // Extract all const assignments with Base64 values
        let varPattern = #"const\s+(\w+)\s*=\s*'([A-Za-z0-9+/=_-]+)'"#
        var vars: [String: String] = [:]
        
        if let regex = try? NSRegularExpression(pattern: varPattern) {
            let matches = regex.matches(in: jsCode, range: NSRange(jsCode.startIndex..., in: jsCode))
            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: jsCode),
                   let valueRange = Range(match.range(at: 2), in: jsCode) {
                    let name = String(jsCode[nameRange])
                    var b64Value = String(jsCode[valueRange])
                    
                    // Handle URL-safe base64 format
                    b64Value = b64Value.replacingOccurrences(of: "-", with: "+")
                    b64Value = b64Value.replacingOccurrences(of: "_", with: "/")
                    while b64Value.count % 4 != 0 {
                        b64Value += "="
                    }
                    
                    if let data = Data(base64Encoded: b64Value),
                       let decoded = String(data: data, encoding: .utf8) {
                        vars[name] = decoded
                    } else {
                        vars[name] = String(jsCode[valueRange])
                    }
                }
            }
        }
        
        // Detect the decoder function name: function FunctionName(str)
        let funcPattern = #"function\s+(\w+)\(str\)"#
        var decoderName = "jNJVVkAypbee" // Fallback
        if let regex = try? NSRegularExpression(pattern: funcPattern),
           let match = regex.firstMatch(in: jsCode, range: NSRange(jsCode.startIndex..., in: jsCode)),
           let range = Range(match.range(at: 1), in: jsCode) {
            decoderName = String(jsCode[range])
        }
        
        // Match: const varName = decoderName(var1) + decoderName(var2) + ...;
        let escapedName = NSRegularExpression.escapedPattern(for: decoderName)
        let concatPattern = "const\\s+\\w+\\s*=\\s*([^;]+\(escapedName)[^;]+);"
        
        if let regex = try? NSRegularExpression(pattern: concatPattern) {
            let matches = regex.matches(in: jsCode, range: NSRange(jsCode.startIndex..., in: jsCode))
            
            for match in matches {
                if let exprRange = Range(match.range(at: 1), in: jsCode) {
                    let expression = String(jsCode[exprRange])
                    
                    // Extract variable names from decoderName(varName) calls
                    let callPattern = "\(escapedName)\\((\\w+)\\)"
                    if let callRegex = try? NSRegularExpression(pattern: callPattern) {
                        let callMatches = callRegex.matches(in: expression, range: NSRange(expression.startIndex..., in: expression))
                        
                        var url = ""
                        for callMatch in callMatches {
                            if let varNameRange = Range(callMatch.range(at: 1), in: expression) {
                                let varName = String(expression[varNameRange])
                                if let value = vars[varName] {
                                    url += value
                                }
                            }
                        }
                        
                        // Check if this looks like a valid stream URL
                        if url.contains(".m3u8") && url.hasPrefix("http") {
                            return url
                        }
                    }
                }
            }
        }
        
        return nil
    }
}
