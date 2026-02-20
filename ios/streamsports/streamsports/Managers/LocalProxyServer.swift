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
        config.httpMaximumConnectionsPerHost = 20 // Increase concurrent connections to prevent segment bottlenecks
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
        webServer.addHandler(forMethod: "GET", path: "/playlist.m3u8", request: GCDWebServerRequest.self) { [weak self] request, completion in
            guard let self = self,
                  let query = request.query,
                  let urlString = query["url"],
                  let url = URL(string: urlString) else {
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }
            
            let cookie = query["cookie"]
            let userAgent = query["ua"]
            let referer = query["ref"]
            
            // Add Cache-Buster to rigorously bypass Edge CDN and strict transparent proxies
            var fetchUrl = url
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var items = components.queryItems ?? []
                items.append(URLQueryItem(name: "_t", value: String(Int(Date().timeIntervalSince1970 * 1000))))
                components.queryItems = items
                if let newUrl = components.url {
                    fetchUrl = newUrl
                }
            }
            
            var req = URLRequest(url: fetchUrl)
            req.cachePolicy = .reloadIgnoringLocalCacheData // CRITICAL: Stop URLSession from caching the Live Playlist
            req.httpShouldHandleCookies = false // Prevent URLSession from injecting stale shared cookies
            
            // HEADERS: exact match with backend (server.ts)
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
            
            // Handle UA (Dynamic from WebView)
            let uaToUse = userAgent ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1"
            req.setValue(uaToUse, forHTTPHeaderField: "User-Agent")
            
            if let c = cookie {
                req.setValue(c, forHTTPHeaderField: "Cookie")
            }
            
            print("➡️ [LocalProxyServer] Fetching Playlist: \(url)")
            print("   Headers: \(req.allHTTPHeaderFields ?? [:])")
            
            self.proxySession.dataTask(with: req) { data, response, error in
                var statusCode = 500
                if let httpMsg = response as? HTTPURLResponse {
                    statusCode = httpMsg.statusCode
                    if statusCode != 200 {
                        print("⚠️ [LocalProxyServer] Upstream Error: \(statusCode)")
                        if let d = data, let s = String(data: d, encoding: .utf8) {
                             print("   Response Body: \(s)")
                        }
                    }
                }
                
                guard let data = data, statusCode == 200,
                      let content = String(data: data, encoding: .utf8) else {
                    completion(GCDWebServerDataResponse(statusCode: statusCode))
                    return
                }
                
                // Rewrite Playlist
                let rewritten = self.rewritePlaylist(content: content, baseUrl: url, cookie: cookie, userAgent: userAgent, referer: referer)
                let proxyResponse = GCDWebServerDataResponse(data: rewritten.data(using: .utf8)!, contentType: "application/vnd.apple.mpegurl")
                
                // CRITICAL: Prevent AVPlayer from caching the internal proxy response
                proxyResponse.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
                proxyResponse.setValue("no-cache", forAdditionalHeader: "Pragma")
                proxyResponse.setValue("0", forAdditionalHeader: "Expires")
                
                completion(proxyResponse)
            }.resume()
        }
        
        // 2. Segment Handler - ASYNC STREAMING (ZERO BUFFERING)
        webServer.addHandler(forMethod: "GET", path: "/segment", request: GCDWebServerRequest.self) { [weak self] request, completion in
            guard let self = self,
                  let query = request.query,
                  let urlString = query["url"],
                  let url = URL(string: urlString) else {
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }
            
            let cookie = query["cookie"]
            let userAgent = query["ua"]
            let referer = query["ref"]
            
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.httpShouldHandleCookies = false
            
            // HEADERS
            req.setValue("https://cdn-live.tv", forHTTPHeaderField: "Origin")
            let refToUse = referer ?? "https://cdn-live.tv/"
            req.setValue(refToUse, forHTTPHeaderField: "Referer")
            req.setValue("*/*", forHTTPHeaderField: "Accept")
            req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            req.setValue("keep-alive", forHTTPHeaderField: "Connection")
            req.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
            req.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
            req.setValue("cross-site", forHTTPHeaderField: "Sec-Fetch-Site")
            
            let uaToUse = userAgent ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1"
            req.setValue(uaToUse, forHTTPHeaderField: "User-Agent")
            
            if let c = cookie {
                req.setValue(c, forHTTPHeaderField: "Cookie")
            }
            
            // ASYNC STREAMING APPROACH
            // Pipe the bytes directly from the URLSession socket to GCDWebServer's socket.
            var didRespond = false
            let delegate = ProxySegmentDelegate { response, error in
                guard !didRespond else { return }
                didRespond = true
                
                if let _ = error {
                    completion(GCDWebServerDataResponse(statusCode: 502))
                    return
                }
                
                guard let response = response else {
                    completion(GCDWebServerDataResponse(statusCode: 500))
                    return
                }
                
                var contentType = "video/mp2t"
                var statusCode = 200
                
                if let httpMsg = response as? HTTPURLResponse {
                    if let ct = httpMsg.mimeType {
                        contentType = ct
                    }
                    statusCode = httpMsg.statusCode
                }
                
                let streamedResponse = GCDWebServerStreamedResponse(contentType: contentType, asyncStreamBlock: { [weak self] bodyBlock in
                    guard let self = self else { bodyBlock(Data(), nil); return }
                    // Read next chunk from delegate buffer
                    ProxySegmentManager.shared.readNextChunk(for: urlString) { data, chunkError in
                        if let e = chunkError {
                            bodyBlock(nil, e)
                        } else if let d = data {
                            bodyBlock(d, nil)
                        } else {
                            bodyBlock(Data(), nil) // EOF
                        }
                    }
                })
                
                streamedResponse.statusCode = statusCode
                let expectedLength = response.expectedContentLength
                if expectedLength > 0 {
                    streamedResponse.contentLength = UInt(expectedLength)
                }
                
                streamedResponse.setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
                completion(streamedResponse)
            }
            
            let session = URLSession(configuration: self.proxySession.configuration, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: req)
            ProxySegmentManager.shared.register(delegate: delegate, urlString: urlString)
            task.resume()
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
        
        // REVERT TO LOCAL PROXY FOR SEGMENTS.
        // Direct AVPlayer CDN fetches failed (15514 / 12312) because CDN rigidly blocks native iOS requests 
        // regardless of AVURLAssetHTTPCookiesKey injection.
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
