import Foundation
import WebKit
import UIKit

/// WebView-based stream resolver for cdn-live.tv
/// Loads the player page in an invisible WebView and intercepts M3U8 requests
/// This ensures the token is generated for the iPhone's IP, bypassing IP binding issues
class WebViewStreamResolver: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    
    static let shared = WebViewStreamResolver()
    
    private var webView: WKWebView?
    private var completion: ((String?, String?, String?) -> Void)?
    private var timeoutTimer: Timer?
    private let timeout: TimeInterval = 20.0  // Augmenté de 15 → 20s
    
    // MARK: - Public API
    
    func resolve(playerUrl: String, completion: @escaping (String?, String?, String?) -> Void) {
        cleanup()
        self.completion = completion
        
        print("[WebViewResolver] Starting resolution for: \(playerUrl)")
        
        // Configuration WebView
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // JavaScript pour intercepter les requêtes réseau vers .m3u8
        let script = """
        (function() {
            // Intercept XMLHttpRequest
            const originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                if (typeof url === 'string' && url.includes('.m3u8')) {
                    window.webkit.messageHandlers.m3u8Handler.postMessage(url);
                }
                return originalOpen.apply(this, arguments);
            };
            
            // Intercept fetch
            const originalFetch = window.fetch;
            window.fetch = function(url, options) {
                const urlStr = (url instanceof Request) ? url.url : String(url);
                if (urlStr.includes('.m3u8')) {
                    window.webkit.messageHandlers.m3u8Handler.postMessage(urlStr);
                }
                return originalFetch.apply(this, arguments);
            };
            
            // Watch video elements
            const observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'attributes' && mutation.attributeName === 'src') {
                        const src = mutation.target.src;
                        if (src && src.includes('.m3u8')) {
                            window.webkit.messageHandlers.m3u8Handler.postMessage(src);
                        }
                    }
                });
            });
            
            document.addEventListener('DOMContentLoaded', function() {
                const videos = document.getElementsByTagName('video');
                for (let video of videos) {
                    observer.observe(video, { attributes: true });
                    if (video.src && video.src.includes('.m3u8')) {
                        window.webkit.messageHandlers.m3u8Handler.postMessage(video.src);
                    }
                }
                // Aussi les sources HLS.js / OPlayer (via src)
                document.querySelectorAll('[src]').forEach(el => {
                    if (el.src && el.src.includes('.m3u8')) {
                        window.webkit.messageHandlers.m3u8Handler.postMessage(el.src);
                    }
                });
            });
        })();
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(self, name: "m3u8Handler")
        
        // Créer le WebView
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.isHidden = true
        wv.alpha = 0
        
        // ⚡ CRITIQUE: Attacher à la fenêtre principale pour éviter que iOS tue les processus WebKit
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first {
                window.addSubview(wv)
                print("[WebViewResolver] ✅ WebView attached to window (prevents WebKit process kill)")
            } else {
                print("[WebViewResolver] ⚠️ No window found — WebView running detached")
            }
            
            // Desktop UA — requis pour que le player génère le bon token
            wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            wv.navigationDelegate = self
            self.webView = wv
            
            // Timeout
            self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeout, repeats: false) { [weak self] _ in
                print("[WebViewResolver] ⏱️ Timeout - no M3U8 found")
                self?.finish(streamUrl: nil, cookie: nil)
            }
            
            // Charger la page
            if let url = URL(string: playerUrl) {
                wv.load(URLRequest(url: url))
            } else {
                print("[WebViewResolver] ❌ Invalid URL")
                self.finish(streamUrl: nil, cookie: nil)
            }
        }
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "m3u8Handler",
              let urlString = message.body as? String else { return }
        
        print("[WebViewResolver] 🎯 Intercepted M3U8: \(urlString.prefix(80))...")
        extractCookie { [weak self] cookie in
            self?.finish(streamUrl: urlString, cookie: cookie)
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[WebViewResolver] ✅ Page loaded")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        // Ignorer les erreurs de navigation annulée (ex: redirect) — le JS peut encore intercepter
        if nsError.code == NSURLErrorCancelled { return }
        print("[WebViewResolver] ❌ Navigation failed: \(error.localizedDescription)")
        finish(streamUrl: nil, cookie: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        // Ignorer les erreurs de navigation annulée (redirect courant dans les players)
        if nsError.code == NSURLErrorCancelled { return }
        print("[WebViewResolver] ❌ Provisional navigation failed: \(error.localizedDescription)")
        // Ne pas appeler finish ici — laisser le timeout gérer si le JS n'intercepte rien
        // Certains players peuvent échouer partiellement mais le JS intercepte quand même
    }
    
    // MARK: - Cookie Extraction
    
    private func extractCookie(completion: @escaping (String?) -> Void) {
        guard let cookieStore = webView?.configuration.websiteDataStore.httpCookieStore else {
            completion(nil)
            return
        }
        
        cookieStore.getAllCookies { cookies in
            if let sessionCookie = cookies.first(where: { $0.name == "PHPSESSID" }) {
                let cookieString = "\(sessionCookie.name)=\(sessionCookie.value)"
                print("[WebViewResolver] 🍪 Extracted cookie: \(cookieString)")
                HTTPCookieStorage.shared.setCookie(sessionCookie)
                completion(cookieString)
            } else {
                print("[WebViewResolver] ℹ️ No PHPSESSID cookie (not required for cdn-live.tv)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Finish & Cleanup
    
    private func finish(streamUrl: String?, cookie: String?) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        if let url = streamUrl {
            print("[WebViewResolver] ✅ Resolution successful")
            webView?.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
                let userAgent = result as? String
                print("[WebViewResolver] 📱 UA: \(userAgent?.prefix(50) ?? "nil")")
                self?.completion?(url, cookie, userAgent)
                self?.cleanup()
            }
        } else {
            print("[WebViewResolver] ❌ Resolution failed")
            completion?(nil, nil, nil)
            cleanup()
        }
    }
    
    private func cleanup() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "m3u8Handler")
        webView?.stopLoading()
        DispatchQueue.main.async {
            self.webView?.removeFromSuperview()
        }
        webView = nil
        completion = nil
    }
}
