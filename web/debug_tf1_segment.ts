import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    try {
        console.log("Fetching channels...");
        const channels = await client.getAllChannels();
        const channel = channels.find(c => c.name.toLowerCase().includes('tf1'));
        if (!channel) { console.log("❌ Channel 'TF1' not found."); return; }

        console.log(`Testing channel: ${channel.name}`);
        const streamUrl = await client.resolveStreamUrl(channel.url);
        if (!streamUrl) { console.log("❌ Could not resolve stream URL."); return; }

        const headers = {
            'Referer': channel.url,
            'Origin': new URL(channel.url).origin,
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        };

        // 1. Fetch Master Playlist
        console.log("1. Fetching Master Playlist...");
        const masterRes = await axios.get(streamUrl, { headers });
        const masterLines = masterRes.data.split('\n');
        let mediaUrl: string | null = null;
        for (const line of masterLines) {
            if (line && !line.startsWith('#') && line.trim()) {
                mediaUrl = line.trim();
                break;
            }
        }
        if (!mediaUrl) { console.log("❌ No media playlist found."); return; }
        if (!mediaUrl.startsWith('http')) {
            mediaUrl = new URL(mediaUrl, streamUrl.substring(0, streamUrl.lastIndexOf('/') + 1)).toString();
        }

        // 2. Fetch Media Playlist
        console.log("2. Fetching Media Playlist...");
        const mediaRes = await axios.get(mediaUrl, { headers });
        console.log("\n--- Media Playlist Content (Excerpt) ---");
        console.log(mediaRes.data.substring(0, 500) + '...');
        console.log("----------------------------------------\n");

        // Check for Keys
        const keyMatch = mediaRes.data.match(/#EXT-X-KEY:.*URI="([^"]+)"/);

        if (keyMatch) {
            console.log(`🔑 FOUND ENCRYPTION KEY! Method: ${keyMatch[1]}`);
            let keyUrl = keyMatch[2];
            console.log(`Key URI: ${keyUrl}`);

            if (!keyUrl.startsWith('http')) {
                keyUrl = new URL(keyUrl, mediaUrl.substring(0, mediaUrl.lastIndexOf('/') + 1)).toString();
            }

            // Test Key Access with Localhost
            console.log("\n3. BIG TEST: Fetching KEY with 'Referer: http://localhost:3000'...");
            try {
                const res = await axios.get(keyUrl, {
                    headers: {
                        'Referer': 'http://localhost:3000',
                        'Origin': 'http://localhost:3000'
                    }
                });
                console.log("✅ SUCCESS: Key fetched with local Referer!");
                console.log(`Access-Control-Allow-Origin: ${res.headers['access-control-allow-origin']}`);
            } catch (e: any) {
                console.log(`❌ FAILED to fetch Key: ${e.message} (Status: ${e.response?.status})`);
                console.log("CONCLUSION: Keys MUST be proxied.");
            }
        } else {
            console.log("ℹ️ No #EXT-X-KEY found. Stream is likely unencrypted or uses a different method.");
        }

    } catch (e) {
        console.error(e);
    }
}

main();
