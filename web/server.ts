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
        const streamUrl = await client.resolveStreamUrl(playerUrl);
        if (streamUrl) {
            const proxyUrl = `/api/proxy?url=${encodeURIComponent(streamUrl)}&referer=${encodeURIComponent(playerUrl)}`;
            res.json({ success: true, streamUrl: proxyUrl });
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

    if (!targetUrl || !referer) {
        res.status(400).send('Missing url or referer');
        return;
    }

    try {
        const response = await axios.get(targetUrl, {
            headers: {
                'Referer': referer,
                'Origin': new URL(referer).origin,
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            responseType: 'arraybuffer'
        });

        res.setHeader('Access-Control-Allow-Origin', '*');

        const contentType = response.headers['content-type'];
        res.setHeader('Content-Type', contentType);

        const isM3U8 = (contentType && (contentType.includes('mpegurl') || contentType.includes('application/x-mpegURL'))) ||
            targetUrl.includes('.m3u8') ||
            (Buffer.isBuffer(response.data) && response.data.slice(0, 7).toString() === '#EXTM3U') ||
            (typeof response.data === 'string' && response.data.startsWith('#EXTM3U'));

        if (isM3U8) {
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

                    // ALWAYS proxy everything (Playlists AND Segments) to handle CORS/Referer
                    return `/api/proxy?url=${encodeURIComponent(absoluteUrl)}&referer=${encodeURIComponent(referer)}`;
                }

                // Case 2: Tag with URI="..." (Encryption Keys, Audio Tracks, Subtitles)
                if (trimmed.startsWith('#') && trimmed.includes('URI=')) {
                    return trimmed.replace(/URI="([^"]+)"/g, (match, uri) => {
                        let absoluteUrl = uri;
                        if (!uri.startsWith('http')) {
                            absoluteUrl = new URL(uri, baseUrl).toString();
                        }

                        // Always proxy M3U8s (Audio Tracks, Variant Playlists)
                        if (absoluteUrl.includes('.m3u8')) {
                            const proxyUri = `/api/proxy?url=${encodeURIComponent(absoluteUrl)}&referer=${encodeURIComponent(referer)}`;
                            return `URI="${proxyUri}"`;
                        }

                        // Always proxy Keys (often secured)
                        if (trimmed.startsWith('#EXT-X-KEY')) {
                            const proxyUri = `/api/proxy?url=${encodeURIComponent(absoluteUrl)}&referer=${encodeURIComponent(referer)}`;
                            return `URI="${proxyUri}"`;
                        }

                        // Segments inside tags? (Rare, but if so, direct access usually fine)
                        return `URI="${absoluteUrl}"`;
                    });
                }

                return line;
            });

            res.send(rewrittenLines.join('\n'));
        } else {
            res.send(response.data);
        }

    } catch (error: any) {
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
