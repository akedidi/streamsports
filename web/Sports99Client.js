"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Sports99Client = void 0;
const axios_1 = __importDefault(require("axios"));
class Sports99Client {
    constructor(user = "streamsports99", plan = "vip", timeout = 30000) {
        this.user = user;
        this.plan = plan;
        this.baseApi = "https://api.cdn-live.tv/api/v1";
        this.playerReferer = "https://streamsports99.su/";
        this.timeout = timeout;
    }
    // ---------------------------------------------------------
    // Utility: Convert base
    // ---------------------------------------------------------
    convertBase(s, base) {
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
    decodeObfuscatedJs(html) {
        const startMarker = '}("';
        const startIdx = html.indexOf(startMarker);
        if (startIdx === -1)
            return null;
        const actualStart = startIdx + startMarker.length;
        const endIdx = html.indexOf('",', actualStart);
        if (endIdx === -1)
            return null;
        const encoded = html.substring(actualStart, endIdx);
        const paramsPos = endIdx + 2;
        const params = html.substring(paramsPos, paramsPos + 100);
        const match = params.match(/(\d+),\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*(\d+)/);
        if (!match)
            return null;
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
        }
        catch {
            // If URI decode fails, return the raw decoded string
            return decoded;
        }
    }
    // ---------------------------------------------------------
    // Find Stream URL
    // ---------------------------------------------------------
    findStreamUrl(jsCode) {
        const pattern = /[\"']([^\"']*index\.m3u8\?token=[^\"']+)[\"']/;
        const match = jsCode.match(pattern);
        return match ? match[1] : null;
    }
    // ---------------------------------------------------------
    // Fetch Live TV Channels
    // ---------------------------------------------------------
    async fetchLiveTvChannels() {
        const url = `${this.baseApi}/channels/?user=${this.user}&plan=${this.plan}`;
        try {
            const res = await axios_1.default.get(url, { timeout: this.timeout });
            const channels = res.data.channels || [];
            return channels.map((c) => ({
                name: c.name,
                channel_name: c.name,
                code: c.code,
                url: c.url,
                image: c.image || "",
                status: c.status
            }));
        }
        catch (e) {
            console.error('[Sports99] Error fetching Live TV:', e.message);
            return [];
        }
    }
    // ---------------------------------------------------------
    // Fetch Sports Events
    // ---------------------------------------------------------
    async fetchSportsEvents() {
        const url = `${this.baseApi}/events/sports/?user=${this.user}&plan=${this.plan}`;
        try {
            const res = await axios_1.default.get(url, { timeout: this.timeout });
            const data = res.data;
            const flattenedChannels = [];
            if (data["cdn-live-tv"]) {
                for (const sportCategory of Object.keys(data["cdn-live-tv"])) {
                    const events = data["cdn-live-tv"][sportCategory];
                    if (!Array.isArray(events))
                        continue;
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
                                sport_category: sportCategory,
                                status: event.status || "unknown",
                                start: event.start || "",
                                time: event.time || ""
                            });
                        }
                    }
                }
            }
            return flattenedChannels;
        }
        catch (e) {
            console.error('[Sports99] Error fetching Sports:', e.message);
            return [];
        }
    }
    // ---------------------------------------------------------
    // Resolve Stream URL
    // ---------------------------------------------------------
    async resolveStreamUrl(playerUrl) {
        try {
            const headers = { Referer: this.playerReferer };
            const res = await axios_1.default.get(playerUrl, { headers, timeout: this.timeout });
            const js = this.decodeObfuscatedJs(res.data);
            if (!js) {
                console.warn('[Sports99] Could not decode obfuscated JS');
                return null;
            }
            return this.findStreamUrl(js);
        }
        catch (e) {
            console.error('[Sports99] Error resolving stream:', e.message);
            return null;
        }
    }
    // ---------------------------------------------------------
    // Get All Channels (Sports + Live TV)
    // ---------------------------------------------------------
    async getAllChannels() {
        const [sports, liveTv] = await Promise.all([
            this.fetchSportsEvents(),
            this.fetchLiveTvChannels()
        ]);
        return [...sports, ...liveTv];
    }
}
exports.Sports99Client = Sports99Client;
