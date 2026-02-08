import axios from 'axios';

export interface Sports99Channel {
    name: string;
    channel_name: string;
    code: string;
    url: string;
    image: string;
    tournament?: string;
    home_team?: string;
    away_team?: string;
    match_info?: string;
    sport_category?: string;
    status?: string;
    start?: string;
    end?: string;
    time?: string;
    stream_url?: string;
    country?: string;
    countryIMG?: string;
    gameID?: string;
}

export class Sports99Client {
    private user: string;
    private plan: string;
    private baseApi: string;
    private playerReferer: string;
    private timeout: number;

    constructor(user: string = "cdnlivetv", plan: string = "free", timeout: number = 30000) {
        this.user = user;
        this.plan = plan;
        this.baseApi = "https://api.cdn-live.tv/api/v1";
        // Browser behavior: 
        // 1. Resolution (Page Load): Referer = streamsports99.su (Embedding site)
        // 2. Playback (Stream): Referer = cdn-live.tv (Player origin)
        // So we revert this to the embedding site, while keeping UA matched.
        this.playerReferer = "https://streamsports99.su/";
        this.timeout = timeout;
    }

    // ---------------------------------------------------------
    // Utility: Convert base
    // ---------------------------------------------------------
    private convertBase(s: string, base: number): number {
        let result = 0;
        const reversed = s.split('').reverse();
        for (let i = 0; i < reversed.length; i++) {
            result += parseInt(reversed[i], 10) * Math.pow(base, i);
        }
        return result;
    }

    // ---------------------------------------------------------
    // JS Obfuscation Decoder
    // ---------------------------------------------------------
    private decodeObfuscatedJs(html: string): string | null {
        const startMarker = '}("';
        const startIdx = html.indexOf(startMarker);
        if (startIdx === -1) return null;

        const actualStart = startIdx + startMarker.length;
        const endIdx = html.indexOf('",', actualStart);
        if (endIdx === -1) return null;

        const encoded = html.substring(actualStart, endIdx);
        const paramsPos = endIdx + 2;
        const params = html.substring(paramsPos, paramsPos + 100);

        const match = params.match(/(\d+),\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*(\d+)/);
        if (!match) return null;

        const charset = match[2];
        const offset = parseInt(match[3], 10);
        const base = parseInt(match[4], 10);

        let decoded = "";
        const parts = encoded.split(charset[base]);

        for (const part of parts) {
            if (part) {
                let temp = part;
                for (let idx = 0; idx < charset.length; idx++) {
                    temp = temp.split(charset[idx]).join(String(idx));
                }
                const val = this.convertBase(temp, base);
                decoded += String.fromCharCode(val - offset);
            }
        }

        // Try to decode URI, but some content may not be URI encoded
        try {
            return decodeURIComponent(decoded);
        } catch {
            // If URI decode fails, return the raw decoded string
            return decoded;
        }
    }

    // ---------------------------------------------------------
    // Find Stream URL
    // ---------------------------------------------------------
    private findStreamUrl(jsCode: string): string | null {
        // First try legacy pattern (direct m3u8 URL in quotes)
        const legacyPattern = /["']([^"']*index\.m3u8\?token=[^"']+)["']/;
        const legacyMatch = jsCode.match(legacyPattern);
        if (legacyMatch) {
            return legacyMatch[1];
        }

        // New pattern: Base64 encoded URL fragments in variables
        // Extract all const assignments with Base64 values
        const varPattern = /const\s+(\w+)\s*=\s*'([A-Za-z0-9+/=_-]+)'/g;
        const vars: Record<string, string> = {};
        let varMatch;
        while ((varMatch = varPattern.exec(jsCode)) !== null) {
            const [, name, b64Value] = varMatch;
            try {
                // Handle URL-safe base64 format
                let b64 = b64Value.replace(/-/g, '+').replace(/_/g, '/');
                while (b64.length % 4) b64 += '=';
                vars[name] = Buffer.from(b64, 'base64').toString('utf8');
            } catch {
                vars[name] = b64Value;
            }
        }

        // Detect the decoder function name
        // Pattern: function FunctionName(str) { ... }
        const funcMatch = jsCode.match(/function\s+(\w+)\(str\)/);
        const decoderName = funcMatch ? funcMatch[1] : 'jNJVVkAypbee'; // Fallback

        // Match: const varName = decoderName(var1) + decoderName(var2) + ...;
        // Escape the function name for regex
        const safeName = decoderName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const concatPattern = new RegExp(`const\\s+\\w+\\s*=\\s*([^;]+${safeName}[^;]+);`, 'g');

        let concatMatch;
        while ((concatMatch = concatPattern.exec(jsCode)) !== null) {
            const expression = concatMatch[1];

            // Extract variable names from decoderName(varName) calls
            const callRegex = new RegExp(`${safeName}\\((\\w+)\\)`, 'g');
            const varNamesMatch = expression.match(callRegex);

            if (varNamesMatch && varNamesMatch.length > 0) {
                let url = '';
                for (const call of varNamesMatch) {
                    const nameRegex = new RegExp(`${safeName}\\((\\w+)\\)`);
                    const nameMatch = call.match(nameRegex);
                    if (nameMatch && vars[nameMatch[1]]) {
                        url += vars[nameMatch[1]];
                    }
                }

                // Check if this looks like a valid stream URL
                if (url.includes('.m3u8') && url.startsWith('http')) {
                    return url;
                }
            }
        }

        return null;
    }

    // ---------------------------------------------------------
    // Fetch Live TV Channels
    // ---------------------------------------------------------
    public async fetchLiveTvChannels(): Promise<Sports99Channel[]> {
        const url = `${this.baseApi}/channels/?user=${this.user}&plan=${this.plan}`;
        try {
            const headers = {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            };
            const res = await axios.get(url, { headers, timeout: this.timeout });
            const channels = res.data.channels || [];
            return channels.map((c: any) => ({
                name: c.name,
                channel_name: c.name,
                code: c.code,
                url: c.url,
                image: c.image || "",
                status: c.status,
                country: c.code // Use code as country (e.g. "us", "uk")
            }));
        } catch (e: any) {
            console.error('[Sports99] Error fetching Live TV:', e.message);
            return [];
        }
    }

    // ---------------------------------------------------------
    // Fetch Sports Events
    // ---------------------------------------------------------
    public async fetchSportsEvents(sport: string = ""): Promise<Sports99Channel[]> {
        let endpoint = "sports";
        if (sport && sport !== "all") {
            endpoint = `sports/${sport}`;
        }

        const url = `${this.baseApi}/events/${endpoint}/?user=${this.user}&plan=${this.plan}`;
        try {
            const headers = {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            };
            const res = await axios.get(url, { headers, timeout: this.timeout });
            const data = res.data;

            const flattenedChannels: Sports99Channel[] = [];
            const root = data["cdn-live-tv"]; // e.g. data["cdn-live-tv"]

            if (root) {
                // If fetching specific sport, root might be the array directly or still keyed object
                // The API structure for "all" is { "soccer": [...], "nfl": [...] }
                // Let's assume specific endpoints return { "soccer": [...] } or similar wrapper.
                // We'll traverse keys to be safe.

                const keys = Object.keys(root);
                for (const key of keys) {
                    const events = root[key];
                    if (!Array.isArray(events)) continue;

                    for (const event of events) {
                        const tournament = event.tournament || "";
                        const homeTeam = event.homeTeam || "";
                        const awayTeam = event.awayTeam || "";
                        // If both teams are the same (e.g., "Simulcast"), show only once
                        const teamDisplay = (homeTeam && awayTeam && homeTeam === awayTeam)
                            ? homeTeam
                            : `${homeTeam} vs ${awayTeam}`;
                        const matchInfo = `${tournament} - ${teamDisplay}`;

                        for (const channel of (event.channels || [])) {
                            flattenedChannels.push({
                                name: `${matchInfo} - ${channel.channel_name}`,
                                channel_name: channel.channel_name,
                                code: channel.channel_code,
                                url: channel.url,
                                image: channel.image || "",
                                tournament,
                                home_team: homeTeam,
                                away_team: awayTeam,
                                match_info: matchInfo,
                                sport_category: key, // Use the key as category (e.g. "Soccer")
                                status: event.status || "unknown",
                                start: event.start || "",
                                end: event.end || "",
                                time: event.time || "",
                                country: event.country || "",
                                countryIMG: event.countryIMG || "",
                                gameID: event.gameID || ""
                            });
                        }
                    }
                }
            }

            return flattenedChannels;
        } catch (e: any) {
            console.error(`[Sports99] Error fetching Sports (${sport}):`, e.message);
            return [];
        }
    }

    // ---------------------------------------------------------
    // Resolve Stream URL
    // ---------------------------------------------------------
    // ---------------------------------------------------------
    // Resolve Stream URL
    // ---------------------------------------------------------
    public async resolveStreamUrl(playerUrl: string): Promise<{ streamUrl: string, cookies?: string[] } | null> {
        try {
            const headers = {
                Referer: this.playerReferer,
                // Match User-Agent with server.ts proxy to avoid session/UA mismatch (401)
                'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1'
            };
            const res = await axios.get(playerUrl, { headers, timeout: this.timeout });

            const js = this.decodeObfuscatedJs(res.data);
            if (!js) {
                console.warn('[Sports99] Could not decode obfuscated JS');
                return null;
            }

            const streamUrl = this.findStreamUrl(js);
            if (streamUrl) {
                // Extract cookies if present
                const cookies = res.headers['set-cookie'];

                // HYBRID APPROACH (like iOS): Wrap stream in proxy for stable playback
                // Build proxy URL with force_proxy=true to ensure ALL segments are proxied
                const proxyParams = new URLSearchParams({
                    url: streamUrl,
                    referer: 'https://cdn-live.tv/',
                    force_proxy: 'true'
                });

                // Add cookie if available
                if (cookies && cookies.length > 0) {
                    // Extract cookie values (remove attributes like Path, HttpOnly, etc.)
                    const cookieValue = cookies.map(c => c.split(';')[0]).join('; ');
                    proxyParams.append('cookie', cookieValue);
                    console.log('[Sports99] Including cookie in proxy request');
                }

                const proxyUrl = `/api/proxy?${proxyParams.toString()}`;
                console.log(`[Sports99] Using HYBRID approach: proxying resolved URL for stable playback`);

                return { streamUrl: proxyUrl, cookies };
            }
            return null;

        } catch (e: any) {
            console.error('[Sports99] Error resolving stream:', e.message);
            return null;
        }
    }

    // ---------------------------------------------------------
    // Get All Channels (Sports + Live TV)
    // ---------------------------------------------------------
    public async getAllChannels(): Promise<Sports99Channel[]> {
        const [sports, liveTv] = await Promise.all([
            this.fetchSportsEvents(),
            this.fetchLiveTvChannels()
        ]);
        return [...sports, ...liveTv];
    }
}
