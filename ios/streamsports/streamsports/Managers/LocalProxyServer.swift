import Foundation
import GCDWebServer

class LocalProxyServer {
    static let shared = LocalProxyServer()
    
    private var webServer: GCDWebServer?
    private var port: UInt = 8080
    
    // Shared session for all proxy requests to prevent socket exhaustion and caching
    private lazy var proxySession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil // Absolutely disable all in-memory URLCaching
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    func start() {
        guard webServer == nil else { 
            if let w = webServer, w.isRunning { return } // Already running
            return 
        }
        
        webServer = GCDWebServer()
        
        // ... Handlers setup ... (Adding handlers first, then loop to start)
        setupHandlers()
        
        // Try ports 8080...8090
        for p in 8080...8090 {
            let port = UInt(p)
            do {
                if webServer?.start(withPort: port, bonjourName: nil) == true {
                    self.port = port
                    print("✅ [LocalProxyServer] Started on port \(port)")
                    return
                } else {
                    print("⚠️ [LocalProxyServer] Failed to start on port \(port), trying next...")
                }
            }
        }
        print("❌ [LocalProxyServer] Failed to start on any port")
    }
    
    private func setupHandlers() {
        guard let webServer = webServer else { return }
        
        // 1. Playlist Handler
        webServer.addHandler(forMethod: "GET", path: "/playlist.m3u8", request: GCDWebServerRequest.self) { [weak self] request in
            guard let self = self,
                  let query = request.query,
                  let urlString = query["url"], // Removed as? String
                  let url = URL(string: urlString) else {
                return GCDWebServerDataResponse(statusCode: 400)
            }
            
            let cookie = query["cookie"] // Removed as? String
            let userAgent = query["ua"]
            let referer = query["ref"]
            
            // Fetch Original Playlist
            let semaphore = DispatchSemaphore(value: 0)
            var responseData: Data?
            var statusCode = 500
            
            // Add Cache-Buster to rigorously bypass Edge CDN and strict transparent proxies
            var fetchUrl = url
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var items = components.queryItems ?? []
                items.append(URLQueryItem(name: "_t", value: String(Int(Date().timeIntervalSince1970))))
                components.queryItems = items
                if let newUrl = components.url {
                    fetchUrl = newUrl
                }
            }
            
            var req = URLRequest(url: fetchUrl)
            req.cachePolicy = .reloadIgnoringLocalCacheData // CRITICAL: Stop URLSession from caching the Live Playlist
            req.httpShouldHandleCookies = false // Prevent URLSession from injecting stale shared cookies
            
            // HEADERS: exact match with backend (server.ts)
            // 'Origin': 'https://cdn-live.tv'
            // 'Referer': 'https://cdn-live.tv/'
            
            req.setValue("https://cdn-live.tv", forHTTPHeaderField: "Origin")
            
            // Prefer passed referer, but default to root if missing (matching backend defaults)
            let refToUse = referer ?? "https://cdn-live.tv/"
            req.setValue(refToUse, forHTTPHeaderField: "Referer")
            
            // Standard Headers
            req.setValue("*/*", forHTTPHeaderField: "Accept")
            req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            req.setValue("keep-alive", forHTTPHeaderField: "Connection")
            
            // Security / Fetch Headers (Backend uses these)
            req.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
            req.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
            req.setValue("cross-site", forHTTPHeaderField: "Sec-Fetch-Site")
            
            // Cache Control
            req.setValue("no-cache", forHTTPHeaderField: "Pragma")
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            
            // Handle UA (Dynamic from WebView)
            let uaToUse = userAgent ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1"
            req.setValue(uaToUse, forHTTPHeaderField: "User-Agent")
            
            // Handle Cookie
            if let c = cookie {
                req.setValue(c, forHTTPHeaderField: "Cookie")
            }
            
            // Debug Headers
            print("➡️ [LocalProxyServer] Fetching Playlist: \(url)")
            print("   Headers: \(req.allHTTPHeaderFields ?? [:])")
            
            self.proxySession.dataTask(with: req) { data, response, error in
                if let httpMsg = response as? HTTPURLResponse {
                    statusCode = httpMsg.statusCode
                    if statusCode != 200 {
                        print("⚠️ [LocalProxyServer] Upstream Error: \(statusCode)")
                        if let d = data, let s = String(data: d, encoding: .utf8) {
                             print("   Response Body: \(s)")
                        }
                    }
                }
                responseData = data
                semaphore.signal()
            }.resume()
            
            _ = semaphore.wait(timeout: .now() + 10)
            
            guard let data = responseData, statusCode == 200,
                  let content = String(data: data, encoding: .utf8) else {
                return GCDWebServerDataResponse(statusCode: statusCode)
            }
            
            // Rewrite Playlist
            let rewritten = self.rewritePlaylist(content: content, baseUrl: url, cookie: cookie, userAgent: userAgent, referer: referer)
            let response = GCDWebServerDataResponse(data: rewritten.data(using: .utf8)!, contentType: "application/vnd.apple.mpegurl")
            
            // CRITICAL: Prevent AVPlayer from caching the internal proxy response
            response.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
            response.setValue("no-cache", forAdditionalHeader: "Pragma")
            response.setValue("0", forAdditionalHeader: "Expires")
            
            return response
        }
        
        // 2. Segment Handler
        webServer.addHandler(forMethod: "GET", path: "/segment", request: GCDWebServerRequest.self) { request in
            guard let query = request.query,
                  let urlString = query["url"],
                  let url = URL(string: urlString) else {
                return GCDWebServerDataResponse(statusCode: 400)
            }
            
            let cookie = query["cookie"]
            let userAgent = query["ua"]
            let referer = query["ref"]
            
            // Fetch Segment
            let semaphore = DispatchSemaphore(value: 0)
            var segData: Data?
            var statusCode = 500
            var contentType = "video/mp2t"
            
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData // Same cache policy for segments just in case
            req.httpShouldHandleCookies = false // Prevent URLSession from injecting stale shared cookies
            
            // HEADERS: exact match with playlist handler & backend
            req.setValue("https://cdn-live.tv", forHTTPHeaderField: "Origin")
            
            let refToUse = referer ?? "https://cdn-live.tv/"
            req.setValue(refToUse, forHTTPHeaderField: "Referer")
            
            req.setValue("*/*", forHTTPHeaderField: "Accept")
            req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            req.setValue("keep-alive", forHTTPHeaderField: "Connection")
            
            req.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
            req.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
            req.setValue("cross-site", forHTTPHeaderField: "Sec-Fetch-Site")
            
            req.setValue("no-cache", forHTTPHeaderField: "Pragma")
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            
            // Handle UA
            let uaToUse = userAgent ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1"
            req.setValue(uaToUse, forHTTPHeaderField: "User-Agent")
            
            // Handle Cookie
            if let c = cookie {
                req.setValue(c, forHTTPHeaderField: "Cookie")
            }
            
            // Debug Headers (Optional, maybe too spammy for segments? Keep it for now)
            // print("➡️ [LocalProxyServer] Fetching Segment: \(url)") 
            
            self.proxySession.dataTask(with: req) { data, response, error in
                if let httpMsg = response as? HTTPURLResponse {
                    statusCode = httpMsg.statusCode
                    if let type = httpMsg.mimeType { contentType = type }
                }
                segData = data
                semaphore.signal()
            }.resume()
            
            _ = semaphore.wait(timeout: .now() + 10)
            
            guard let data = segData, statusCode == 200 else {
                return GCDWebServerDataResponse(statusCode: statusCode)
            }
            
            let response = GCDWebServerDataResponse(data: data, contentType: contentType)
            // Segments can be cached slightly but typically not an issue. Let's disable caching to be safe against stale tokens
            response.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
            return response
        }
    }
    
    func stop() {
        if let w = webServer, w.isRunning {
             w.stop()
        }
        webServer = nil
    }
    
    func getProxyUrl(for originalUrl: String, cookie: String?, userAgent: String?, referer: String?) -> String {
        let hostUrl = webServer?.serverURL?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "http://localhost:\(port)"
        
        guard var components = URLComponents(string: hostUrl) else { return originalUrl }
        components.path = "/playlist.m3u8"
        
        var queryItems = [URLQueryItem(name: "url", value: originalUrl)]
        if let c = cookie { queryItems.append(URLQueryItem(name: "cookie", value: c)) }
        if let ua = userAgent { queryItems.append(URLQueryItem(name: "ua", value: ua)) }
        if let ref = referer { queryItems.append(URLQueryItem(name: "ref", value: ref)) }
        
        components.queryItems = queryItems
        return components.url?.absoluteString ?? originalUrl
    }
    
    // MARK: - Helper Logic
    
    private func rewritePlaylist(content: String, baseUrl: URL, cookie: String?, userAgent: String?, referer: String?) -> String {
        var newLines: [String] = []
        let lines = content.components(separatedBy: "\n")
        
        let hostUrl = webServer?.serverURL?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "http://localhost:\(port)"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmed.hasPrefix("#") && !trimmed.isEmpty {
                // It's a segment URL
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
                if let c = cookie { queryItems.append(URLQueryItem(name: "cookie", value: c)) }
                if let ua = userAgent { queryItems.append(URLQueryItem(name: "ua", value: ua)) }
                if let ref = referer { queryItems.append(URLQueryItem(name: "ref", value: ref)) }
                
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
        
        return newLines.joined(separator: "\n")
    }
}
