import Foundation

let content = """
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXT-X-VERSION:3
#EXT-X-MEDIA-SEQUENCE:20432
#EXT-X-PROGRAM-DATE-TIME:2026-02-20T12:32:50.927Z
#EXTINF:5.005,
https://edge.cdn-google.ru/secure/api/v1/us-abc/MjAy...1.ts?token=123&signature=456
"""

let hostUrl = "http://192.168.1.12:8080"
let cookie = "PHPSESSID=abc"
let userAgent = "Mozilla"
let referer = "https://cdn-live.tv/"
let baseUrl = URL(string: "https://edge.cdn-google.ru/secure/api/v1/us-abc/playlist.m3u8")!

var newLines: [String] = []
let lines = content.components(separatedBy: "\n")

for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if !trimmed.hasPrefix("#") && !trimmed.isEmpty {
        guard let absoluteSegUrl = URL(string: trimmed, relativeTo: baseUrl)?.absoluteString else {
            newLines.append(trimmed)
            continue
        }
        
        guard var components = URLComponents(string: hostUrl) else {
            newLines.append(trimmed)
            continue
        }
        
        components.path = "/segment"
        var queryItems = [URLQueryItem(name: "url", value: absoluteSegUrl)]
        queryItems.append(URLQueryItem(name: "cookie", value: cookie))
        queryItems.append(URLQueryItem(name: "ua", value: userAgent))
        queryItems.append(URLQueryItem(name: "ref", value: referer))
        
        components.queryItems = queryItems
        
        if let proxyLine = components.url?.absoluteString {
            newLines.append(proxyLine)
        } else {
            newLines.append(trimmed)
        }
    } else {
        newLines.append(line)
    }
}

print(newLines.joined(separator: "\n"))
