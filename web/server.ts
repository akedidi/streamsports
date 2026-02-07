import express from 'express';
import path from 'path';
import axios from 'axios';
import { Sports99Client } from './Sports99Client';
import { URL } from 'url';

const app = express();
const port = 3000;
const client = new Sports99Client();

// Serve static files
const publicPath = path.join(__dirname, 'public');
app.use(express.static(publicPath));
app.use(express.static(path.join(process.cwd(), 'public'))); // Fallback
app.use(express.json());

// Enable CORS for Chromecast
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Range');
    if (req.method === 'OPTIONS') {
        res.sendStatus(200);
    } else {
        next();
    }
});

// Root Route - Serve API
app.get('/', (req, res) => {
    res.sendFile(path.join(publicPath, 'index.html'), (err) => {
        if (err) res.sendFile(path.join(process.cwd(), 'public', 'index.html'));
    });
});

// API: Get all channels (TV Only)
app.get('/api/channels', async (req, res) => {
    try {
        console.log('[API] Fetching Live TV channels...');
        // STRICT SEPARATION: Only fetch Live TV, do NOT include sports events here.
        const channels = await client.fetchLiveTvChannels();
        res.json({ success: true, count: channels.length, channels });
    } catch (error: any) {
        console.error('[API] Error fetching channels:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// API: Get events
app.get('/api/events', async (req, res) => {
    try {
        const sport = req.query.sport as string || "";
        console.log(`[API] Fetching events for sport: ${sport}...`);
        const events = await client.fetchSportsEvents(sport);
        res.json({ success: true, count: events.length, events });
    } catch (error: any) {
        console.error('[API] Error fetching events:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// API: Resolve stream URL
app.get('/api/stream', async (req, res) => {
    const playerUrl = req.query.url as string;
    if (!playerUrl) {
        res.status(400).json({ success: false, message: 'Missing "url" query parameter' });
        return;
    }

    try {
        console.log(`[API] Resolving stream for: ${playerUrl}`);
        const result = await client.resolveStreamUrl(playerUrl);

        if (result && result.streamUrl) {
            let proxyUrl = `/api/proxy?url=${encodeURIComponent(result.streamUrl)}&referer=${encodeURIComponent(playerUrl)}`;
            // Pass cookies to proxy if present
            if (result.cookies && result.cookies.length > 0) {
                // Simplify cookies to name=value; name2=value2
                const cookieString = result.cookies.map(c => c.split(';')[0]).join('; ');
                proxyUrl += `&cookie=${encodeURIComponent(cookieString)}`;
            }

            // Expose Raw URL for Chromecast (Residential IP)
            res.json({ success: true, streamUrl: proxyUrl, rawUrl: result.streamUrl });
        } else {
            res.status(404).json({ success: false, message: 'Could not resolve stream URL' });
        }
    } catch (error: any) {
        console.error('[API] Error resolving stream:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// API: Light Proxy
app.get('/api/proxy', async (req, res) => {
    const targetUrl = req.query.url as string;
    const referer = req.query.referer as string;
    const cookie = req.query.cookie as string;

    if (!targetUrl || !referer) {
        console.error('[Proxy] Missing targetUrl or referer');
        res.status(400).send('Missing url or referer');
        return;
    }

    // console.log(`[Proxy] Incoming Request: ${targetUrl}`); // Verbose
    const userAgent = req.headers['user-agent'] || 'Unknown';
    const origin = req.headers['origin'] || 'Unknown';

    // Log typical Chromecast or Browser UA fragments to distinguish
    const isCast = userAgent.includes('CrKey') || userAgent.includes('Google-Cast');
    if (isCast) {
        console.log(`[Proxy] 📡 CHROMECAST Request for: ${targetUrl.split('/').pop()}`);
    } else {
        console.log(`[Proxy] 🌍 BROWSER Request for: ${targetUrl.split('/').pop()}`);
    }
    // console.log(`[Proxy] UA: ${userAgent} | Origin: ${origin}`);

    try {
        const headers: any = {
            // Use the same browser UA as the client to avoid 401 Unauthorized
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Connection': 'keep-alive',
            'Origin': 'https://cdn-live.tv',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'cross-site',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache'
        };

        // FORCE Referer to 'https://cdn-live.tv/' because the edge server blocks 'streamsports99.su'
        // The previous logic passed the client's referer, which caused 403 Forbidden.
        headers['Referer'] = 'https://cdn-live.tv/';

        if (cookie) {
            headers['Cookie'] = cookie;
        }

        const response = await axios.get(targetUrl, {
            headers,
            responseType: 'arraybuffer'
        });

        res.setHeader('Access-Control-Allow-Origin', '*');

        const contentType = response.headers['content-type'];
        res.setHeader('Content-Type', contentType);

        // console.log(`[Proxy] Response Content-Type: ${contentType}`);

        const isM3U8 = (contentType && (contentType.includes('mpegurl') || contentType.includes('application/x-mpegURL'))) ||
            targetUrl.includes('.m3u8') ||
            (Buffer.isBuffer(response.data) && response.data.slice(0, 7).toString() === '#EXTM3U') ||
            (typeof response.data === 'string' && response.data.startsWith('#EXTM3U'));

        if (isM3U8) {
            console.log(`[Proxy] Detected M3U8 Playlist: ${targetUrl.split('/').pop()}`);
            let m3u8Content = response.data.toString('utf8');
            let baseUrl = targetUrl.substring(0, targetUrl.lastIndexOf('/') + 1);

            const lines = m3u8Content.split('\n');
            const rewrittenLines = lines.map((line: string) => {
                const trimmed = line.trim();

                // Case 1: Standard URL line (Segment or Playlist)
                if (trimmed && !trimmed.startsWith('#')) {
                    let absoluteUrl = trimmed;
                    if (!trimmed.startsWith('http')) {
                        absoluteUrl = new URL(trimmed, baseUrl).toString();
                    }

                    // Proxy Playlists ONLY (Segments direct for speed)
                    // REVERTED: User reported full proxying was too slow.
                    // This puts the risk of idleReason=4 back on the table if provider checks Referer on segments.
                    if (absoluteUrl.includes('.m3u8')) {
                        console.log(`[Proxy] Rewriting Playlist: ${trimmed}`);
                        return `/api/proxy?url=${encodeURIComponent(absoluteUrl)}&referer=${encodeURIComponent(referer)}`;
                    } else {
                        // Direct link for segments (Save bandwidth / reduce server load for Browser/iOS)
                        return absoluteUrl;
                    }
                }

                // Case 2: Tag with URI="..." (Encryption Keys, Audio Tracks, Subtitles, Init Segments)
                if (trimmed.startsWith('#') && trimmed.includes('URI=')) {
                    return trimmed.replace(/URI=["']([^"']+)["']/g, (match, uri) => {
                        let absoluteUrl = uri;
                        if (!uri.startsWith('http')) {
                            absoluteUrl = new URL(uri, baseUrl).toString();
                        }

                        // Check tag type to decide if we MUST proxy
                        const isSensitiveTag = trimmed.startsWith('#EXT-X-KEY') ||
                            trimmed.startsWith('#EXT-X-MAP') ||
                            trimmed.startsWith('#EXT-X-MEDIA');

                        // Always proxy M3U8s (Sub-playlists), Keys, Maps (Init Segments), and Media (Subtitles)
                        if (absoluteUrl.includes('.m3u8') || isSensitiveTag) {
                            console.log(`[Proxy] Rewriting Tag URI (${trimmed.split(':')[0]}): ${uri}`);
                            const proxyUri = `/api/proxy?url=${encodeURIComponent(absoluteUrl)}&referer=${encodeURIComponent(referer)}`;
                            return `URI="${proxyUri}"`;
                        }

                        // Standard segments inside tags (rare)? Direct link
                        return `URI="${absoluteUrl}"`;
                    });
                }

                return line;
            });

            res.send(rewrittenLines.join('\n'));
        } else {
            // Binary content (segments, keys, etc.)
            // console.log(`[Proxy] Serving Binary/Other Content (${response.data.length} bytes)`);
            res.send(response.data);
        }

    } catch (error: any) {
        console.error(`[Proxy] Error fetching ${targetUrl}:`, error.message);
        if (error.response) {
            res.status(error.response.status).send(error.message);
        } else {
            res.status(500).send(error.message);
        }
    }
});

// Export the app for Vercel Serverless
export default app;

// Only listen if run directly (local dev)
if (require.main === module) {
    app.listen(port, () => {
        console.log(`\n-----------------------------------------------------------`);
        console.log(`🚀 Server running at http://localhost:${port}`);
        console.log(`-----------------------------------------------------------\n`);
    });
}
