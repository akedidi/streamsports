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

    constructor(user: string = "streamsports99", plan: string = "vip", timeout: number = 30000) {
        this.user = user;
        this.plan = plan;
        this.baseApi = "https://api.cdn-live.tv/api/v1";
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
        const pattern = /[\"']([^\"']*index\.m3u8\?token=[^\"']+)[\"']/;
        const match = jsCode.match(pattern);
        return match ? match[1] : null;
    }

    // ---------------------------------------------------------
    // Fetch Live TV Channels
    // ---------------------------------------------------------
    public async fetchLiveTvChannels(): Promise<Sports99Channel[]> {
        const url = `${this.baseApi}/channels/?user=${this.user}&plan=${this.plan}`;
        try {
            const res = await axios.get(url, { timeout: this.timeout });
            const channels = res.data.channels || [];
            return channels.map((c: any) => ({
                name: c.name,
                channel_name: c.name,
                code: c.code,
                url: c.url,
                image: c.image || "",
                status: c.status
            }));
        } catch (e: any) {
            console.error('[Sports99] Error fetching Live TV:', e.message);
            return [];
        }
    }

    // ---------------------------------------------------------
    // Fetch Sports Events
    // ---------------------------------------------------------
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
            const res = await axios.get(url, { timeout: this.timeout });
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
                        const matchInfo = `${tournament} - ${homeTeam} vs ${awayTeam}`;

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
    public async resolveStreamUrl(playerUrl: string): Promise<string | null> {
        try {
            const headers = { Referer: this.playerReferer };
            const res = await axios.get(playerUrl, { headers, timeout: this.timeout });
            const js = this.decodeObfuscatedJs(res.data);
            if (!js) {
                console.warn('[Sports99] Could not decode obfuscated JS');
                return null;
            }
            return this.findStreamUrl(js);
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
