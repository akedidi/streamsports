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
            let proxyUrl: string;

            // Check if URL is already proxied (by Sports99Client)
            if (result.streamUrl.startsWith('/api/proxy')) {
                console.log('[API] Stream URL is already proxied, returning as-is');
                proxyUrl = result.streamUrl;

                // Ensure force_proxy is present if requested
                if (req.query.force_proxy === 'true' && !proxyUrl.includes('force_proxy=true')) {
                    proxyUrl += '&force_proxy=true';
                }
            } else {
                // Wrap in proxy
                proxyUrl = `/api/proxy?url=${encodeURIComponent(result.streamUrl)}&referer=${encodeURIComponent(playerUrl)}`;

                // Pass cookies to proxy if present
                if (result.cookies && result.cookies.length > 0) {
                    // Simplify cookies to name=value; name2=value2
                    const cookieString = result.cookies.map(c => c.split(';')[0]).join('; ');
                    proxyUrl += `&cookie=${encodeURIComponent(cookieString)}`;
                }

                // Propagate force_proxy flag (for iOS/Native)
                if (req.query.force_proxy === 'true') {
                    proxyUrl += '&force_proxy=true';
                }
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

// API: EPG Data Proxy (bypass CORS)
app.get('/api/epg', async (req, res) => {
    try {
        const version = req.query.v || 'v12';
        const epgUrl = `https://kuzwbdweiphaouenogef.supabase.co/functions/v1/epg-data?v=${version}`;

        console.log(`[EPG Proxy] Fetching EPG data (version: ${version})`);

        const response = await axios.get(epgUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                'Accept': 'application/json'
            },
            timeout: 30000
        });

        // Return EPG data with CORS headers
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Content-Type', 'application/json');
        res.json(response.data);
    } catch (error: any) {
        console.error('[EPG Proxy] Error:', error.message);
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
            // FORCE Exact Desktop Chrome UA to match Sports99Client token generation
            // cdn-live.tv seems to bind the token to the UA significantly.
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Connection': 'keep-alive',
            'Origin': 'https://cdn-live.tv',
            'Referer': 'https://cdn-live.tv/',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'cross-site',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache'
        };

        // FORCE Referer to 'https://cdn-live.tv/' because the edge server blocks 'streamsports99.su'
        // The previous logic passed the client's referer, which caused 403 Forbidden.
        // TEST: Let's try trusting the passed referer (which is the player URL) instead of forcing root.
        // headers['Referer'] = 'https://cdn-live.tv/';
        if (referer) {
            headers['Referer'] = referer;
        }

        if (cookie) {
            headers['Cookie'] = cookie;
        }

        // Forward Client IP (Try to bypass IP checks if Edge server trusts us)
        const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
        if (clientIp) {
            headers['X-Forwarded-For'] = clientIp;
            headers['X-Real-IP'] = clientIp;
        }

        // Forward Range header if present (Critical for seeking/playback)
        if (req.headers['range']) {
            headers['Range'] = req.headers['range'];
        }

        let finalTargetUrl = targetUrl;
        const useExternalProxy = req.query.external_proxy === 'true';
        if (useExternalProxy) {
            console.log(`[Proxy] Using External Proxy: https://corsproxy.io/?...`);
            finalTargetUrl = `https://corsproxy.io/?${encodeURIComponent(targetUrl)}`;
        }

        // Use stream to avoid buffering large files in memory
        const response = await axios.get(finalTargetUrl, {
            headers,
            responseType: 'stream',
            validateStatus: (status) => status < 400 || status === 416 // Allow 206 Partial Content
        });

        // Forward important response headers
        res.setHeader('Access-Control-Allow-Origin', '*');

        const contentType = response.headers['content-type'] || 'application/octet-stream';
        res.setHeader('Content-Type', contentType);

        if (response.headers['content-length']) res.setHeader('Content-Length', response.headers['content-length']);
        if (response.headers['content-range']) res.setHeader('Content-Range', response.headers['content-range']);
        if (response.headers['accept-ranges']) res.setHeader('Accept-Ranges', response.headers['accept-ranges']);
        res.status(response.status); // Forward 200 vs 206

        const isM3U8 = (contentType && (contentType.includes('mpegurl') || contentType.includes('application/x-mpegURL'))) ||
            targetUrl.includes('.m3u8');

        if (isM3U8) {
            // Buffer stream for M3U8 rewriting
            const chunks: any[] = [];
            response.data.on('data', (chunk: any) => chunks.push(chunk));
            response.data.on('end', () => {
                const buffer = Buffer.concat(chunks);
                const m3u8Content = buffer.toString('utf8');

                console.log(`[Proxy] Detected M3U8 Playlist: ${targetUrl.split('/').pop()}`);
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

                        // CHECK: If 'force_proxy' is set (e.g. for iOS/Native), proxy everything
                        const forceProxy = req.query.force_proxy === 'true';

                        // CRITICAL: Skip if URL is already a proxy URL (prevent double wrapping)
                        if (absoluteUrl.startsWith('/api/proxy')) {
                            // log only on debug
                            // console.log(`[Proxy] URL already proxied, skipping rewrite: ${trimmed}`);
                            return absoluteUrl;
                        }

                        if (absoluteUrl.includes('.m3u8') || forceProxy) {
                            // console.log(`[Proxy] Rewriting ${forceProxy ? 'Segment (Forced)' : 'Playlist'}: ${trimmed}`);
                            // CRITICAL: Propagate cookie to rewritten URLs for authenticated access
                            const cookieParam = cookie ? `&cookie=${encodeURIComponent(cookie)}` : '';
                            return `/api/proxy?url=${encodeURIComponent(absoluteUrl)}&referer=${encodeURIComponent(referer)}&force_proxy=${forceProxy}${cookieParam}`;
                        } else {
                            // Direct link for segments (Save bandwidth / reduce server load for Browser/iOS)
                            return absoluteUrl;
                        }
                    }

                    // Case 2: Tag with URI="..." 
                    if (trimmed.startsWith('#') && trimmed.includes('URI=')) {
                        return trimmed.replace(/URI=["']([^"']+)["']/g, (match, uri) => {
                            let absoluteUrl = uri;
                            if (!uri.startsWith('http')) {
                                absoluteUrl = new URL(uri, baseUrl).toString();
                            }

                            const isSensitiveTag = trimmed.startsWith('#EXT-X-KEY') ||
                                trimmed.startsWith('#EXT-X-MAP') ||
                                trimmed.startsWith('#EXT-X-MEDIA');

                            if (absoluteUrl.includes('.m3u8') || isSensitiveTag) {
                                // console.log(`[Proxy] Rewriting Tag URI (${trimmed.split(':')[0]}): ${uri}`);
                                const proxyUri = `/api/proxy?url=${encodeURIComponent(absoluteUrl)}&referer=${encodeURIComponent(referer)}`;
                                return `URI="${proxyUri}"`;
                            }
                            return `URI="${absoluteUrl}"`;
                        });
                    }
                    return line;
                });

                // Send rewritten M3U8
                const finalContent = rewrittenLines.join('\n');
                // Update content-length because we changed the body
                res.setHeader('Content-Length', Buffer.byteLength(finalContent));
                res.send(finalContent);
            });

            response.data.on('error', (err: any) => {
                console.error('[Proxy] Error reading M3U8 stream:', err);
                res.end();
            });

        } else {
            // Binary content (segments) - PIPE DIRECTLY!
            // console.log(`[Proxy] Piping Binary Content (${contentType})`);
            response.data.pipe(res);

            response.data.on('error', (err: any) => {
                console.error('[Proxy] Stream error:', err);
                res.end();
            });
        }

    } catch (error: any) {
        // Handle axios errors
        if (error.response) {
            console.error(`[Proxy] Upstream Error ${error.response.status} for ${targetUrl}`);
            res.status(error.response.status).send(error.response.statusText);
        } else {
            console.error(`[Proxy] Network Error fetching ${targetUrl}:`, error.message);
            res.status(500).send('Proxy Error');
        }
    }
});

// DEBUG API: Test Proxy Functionality Internally
app.get('/api/debug-stream', async (req, res) => {
    const playerUrl = req.query.url as string;
    if (!playerUrl) return res.status(400).send('Missing url');

    // Extract Client IP (from Vercel/Proxy headers)
    const clientIp = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress;

    const headers: any = {
        // MATCHING Sports99Client User-Agent
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://streamsports99.su/',
    };

    if (clientIp) {
        headers['X-Forwarded-For'] = clientIp;
        headers['X-Real-IP'] = clientIp;
    }

    try {
        const response = await axios.get(playerUrl, { headers, timeout: 5000, responseType: 'text' });
        res.send({
            status: response.status,
            headers: response.headers,
            dataLength: response.data.length,
            preview: response.data.substring(0, 500)
        });
    } catch (e: any) {
        res.status(500).send({
            error: e.message,
            response: e.response ? {
                status: e.response.status,
                headers: e.response.headers,
                data: e.response.data
            } : null
        });
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
