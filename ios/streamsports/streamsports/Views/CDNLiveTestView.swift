//
//  CDNLiveTestView.swift
//  streamsports
//
//  Script de test standalone pour extraire et jouer le flux cdn-live.tv
//
//  DÉCOUVERTES TECHNIQUES (tests Node.js/Puppeteer):
//  - M3U8: https://edge.cdn-live.ru/secure/api/v1/us-abc/playlist.m3u8?token=...&signature=...
//  - Manifest: MEDIA playlist directe (pas master multi-qualité)
//  - Segments: https://edge.cdn-google.ru/.../xxx.ts?token=...&signature=...
//  - Status 200 SANS aucun header ni cookie (auth = token dans URL)
//  - Token expiry: ~1 minute environ (live stream → manifest re-fetchée automatiquement par AVPlayer)
//  - Stratégie: WebView intercepte l'URL → AVPlayer joue directement (pas besoin de proxy local)
//

import SwiftUI
import AVKit

struct CDNLiveTestView: View {
    
    // MARK: - State
    
    @State private var status: String = "Prêt. Appuie sur Extraire."
    @State private var statusColor: Color = .secondary
    
    @State private var resolvedM3U8: String = ""
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var showPlayer = false
    @State private var logs: [String] = []
    
    let playerUrl = "https://cdn-live.tv/api/v1/channels/player/?name=abc&code=us&user=cdnlivetv&plan=free"
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        urlCard
                        actionButtons
                        statusCard
                        if showPlayer, let player = player {
                            playerCard(player: player)
                        }
                        if !resolvedM3U8.isEmpty {
                            resultsCard
                        }
                        logsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("CDN-Live TV Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // MARK: - Subviews
    
    var urlCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL TESTÉE").font(.caption).bold().foregroundColor(.gray)
            Text(playerUrl).font(.caption2).foregroundColor(.cyan).lineLimit(3)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(10)
    }
    
    var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: runExtraction) {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    Text(isLoading ? "WebView en cours..." : "🚀 Extraire le flux")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            .disabled(isLoading)
            
            HStack(spacing: 10) {
                // Jouer directement (recommandé — pas de proxy nécessaire)
                Button(action: playDirect) {
                    Label("▶ Lecture directe", systemImage: "play.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(resolvedM3U8.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(resolvedM3U8.isEmpty ? .gray : .white)
                        .cornerRadius(10)
                }
                .disabled(resolvedM3U8.isEmpty)
                
                // Jouer via proxy local (fallback si direct pose problème)
                Button(action: playViaProxy) {
                    Label("Via Proxy", systemImage: "server.rack")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(resolvedM3U8.isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                        .foregroundColor(resolvedM3U8.isEmpty ? .gray : .white)
                        .cornerRadius(10)
                }
                .disabled(resolvedM3U8.isEmpty)
            }
        }
    }
    
    var statusCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(statusColor).frame(width: 8, height: 8).padding(.top, 4)
            Text(status).font(.caption).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(10)
    }
    
    func playerCard(player: AVPlayer) -> some View {
        VStack {
            VideoPlayer(player: player)
                .frame(height: 220)
                .cornerRadius(12)
                .onAppear { player.play() }
            Text("▶️ Lecture en cours")
                .font(.caption).foregroundColor(.green)
        }
    }
    
    var resultsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RÉSULTATS").font(.caption).bold().foregroundColor(.gray)
            
            // Analyse du token
            let tokenExpiry = parseTokenExpiry(from: resolvedM3U8)
            
            resultRow(icon: "link", label: "M3U8 URL", value: resolvedM3U8, color: .cyan)
            resultRow(icon: "key.fill", label: "Token expiry", value: tokenExpiry ?? "Inconnu", color: tokenExpiry != nil ? .green : .red)
            resultRow(icon: "lock.open.fill", label: "Cookie requis", value: "❌ Aucun (auth = token URL)", color: .green)
            resultRow(icon: "server.rack", label: "Segments domaine", value: "edge.cdn-google.ru", color: .purple)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(10)
    }
    
    func resultRow(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundColor(color)
                Text(label).font(.caption2).bold().foregroundColor(.gray)
            }
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)
        }
    }
    
    var logsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LOGS").font(.caption).bold().foregroundColor(.gray)
                Spacer()
                Button("Clear") { logs.removeAll() }.font(.caption).foregroundColor(.red)
            }
            if logs.isEmpty {
                Text("Aucun log").font(.caption2).foregroundColor(.gray)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logs.indices.reversed(), id: \.self) { i in
                        Text(logs[i])
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(10)
    }
    
    // MARK: - Actions
    
    func runExtraction() {
        isLoading = true
        showPlayer = false
        player = nil
        resolvedM3U8 = ""
        
        log("🚀 Chargement page player via WebView...")
        setStatus("⏳ WebView en cours (~5-10s)...", color: .yellow)
        
        WebViewStreamResolver.shared.resolve(playerUrl: playerUrl) { streamUrl, cookie, userAgent in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let streamUrl = streamUrl else {
                    setStatus("❌ Aucun M3U8 intercepté (timeout)", color: .red)
                    log("❌ WebViewResolver timeout")
                    return
                }
                
                resolvedM3U8 = streamUrl
                
                let expiry = parseTokenExpiry(from: streamUrl) ?? "?"
                log("🎯 M3U8: \(streamUrl.prefix(80))...")
                log("⏰ Token expiry: \(expiry)")
                log("🍪 Cookie: \(cookie ?? "aucun (non requis)")")
                
                setStatus("✅ Extraction OK! Prêt à jouer.", color: .green)
            }
        }
    }
    
    func playDirect() {
        guard !resolvedM3U8.isEmpty, let url = URL(string: resolvedM3U8) else {
            log("❌ URL M3U8 invalide")
            return
        }
        
        log("▶️ Lecture directe: \(resolvedM3U8.prefix(60))...")
        setStatus("▶️ Lecture directe (AVPlayer gère le refresh automatique)", color: .blue)
        
        // Lecture directe — pas de headers/cookies requis (token dans URL)
        // AVPlayer va auto-refresh le manifest (live HLS)
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        showPlayer = true
    }
    
    func playViaProxy() {
        guard !resolvedM3U8.isEmpty else { return }
        
        log("🔧 Démarrage proxy local...")
        LocalProxyServer.shared.start()
        
        let proxyUrl = LocalProxyServer.shared.getProxyUrl(
            for: resolvedM3U8,
            cookie: nil,      // Aucun cookie requis pour cdn-live.tv
            userAgent: nil,   // UA par défaut suffisant
            referer: "https://cdn-live.tv/"
        )
        
        guard let url = URL(string: proxyUrl) else {
            log("❌ URL proxy invalide")
            return
        }
        
        log("▶️ Via proxy: \(proxyUrl.prefix(60))...")
        setStatus("▶️ Lecture via proxy local...", color: .orange)
        
        player = AVPlayer(url: url)
        showPlayer = true
    }
    
    // MARK: - Helpers
    
    func setStatus(_ msg: String, color: Color) {
        status = msg
        statusColor = color
    }
    
    func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(ts)] \(msg)"
        print(line)
        DispatchQueue.main.async {
            logs.append(line)
            if logs.count > 30 { logs.removeFirst() }
        }
    }
    
    /// Parse le TTL du token depuis une URL cdn-live
    /// Token format: hash.EXPIRY_UNIX.hash2.hash3.hash4
    func parseTokenExpiry(from urlStr: String) -> String? {
        guard let tokenRange = urlStr.range(of: "token="),
              let tokenPart = urlStr[tokenRange.upperBound...].components(separatedBy: "&").first else {
            return nil
        }
        let parts = tokenPart.components(separatedBy: ".")
        guard parts.count >= 2, let expiry = TimeInterval(parts[1]) else { return nil }
        
        let expiryDate = Date(timeIntervalSince1970: expiry)
        let ttl = expiryDate.timeIntervalSinceNow
        if ttl > 0 {
            let h = Int(ttl) / 3600
            let m = (Int(ttl) % 3600) / 60
            let s = Int(ttl) % 60
            return "\(h)h\(m)m\(s)s (expire \(DateFormatter.localizedString(from: expiryDate, dateStyle: .none, timeStyle: .short)))"
        } else {
            return "⚠️ Expiré il y a \(Int(-ttl))s"
        }
    }
}

#Preview {
    CDNLiveTestView()
        .preferredColorScheme(.dark)
}
