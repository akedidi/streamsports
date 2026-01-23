import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    try {
        // 1. Get Channel & Stream
        const channels = await client.getAllChannels();
        const channel = channels.find(c => c.name.toLowerCase().includes('tf1'));
        if (!channel) { console.log("❌ Channel 'TF1' not found."); return; }

        console.log(`Testing Channel: ${channel.name}`);
        const streamUrl = await client.resolveStreamUrl(channel.url);
        if (!streamUrl) { console.log("❌ Could not resolve stream URL."); return; }

        const headers = {
            'Referer': channel.url,
            'Origin': new URL(channel.url).origin,
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        };

        // 2. Get Key URL
        const masterRes = await axios.get(streamUrl, { headers });
        const masterLines = masterRes.data.split('\n');
        let mediaUrl = masterLines.find(l => l.trim() && !l.startsWith('#'))?.trim();
        if (!mediaUrl) return;
        if (!mediaUrl.startsWith('http')) mediaUrl = new URL(mediaUrl, streamUrl.substring(0, streamUrl.lastIndexOf('/') + 1)).toString();

        const mediaRes = await axios.get(mediaUrl, { headers });
        const keyMatch = mediaRes.data.match(/URI="([^"]+)"/);

        if (!keyMatch) {
            console.log("ℹ️ No Key found in playlist.");
            return;
        }

        let keyUrl = keyMatch[1];
        if (!keyUrl.startsWith('http')) {
            keyUrl = new URL(keyUrl, mediaUrl.substring(0, mediaUrl.lastIndexOf('/') + 1)).toString();
        }
        console.log(`Original Key URL: ${keyUrl}`);

        // 3. Test Proxy Access
        const proxyUrl = `http://localhost:3000/api/proxy?url=${encodeURIComponent(keyUrl)}&referer=${encodeURIComponent(channel.url)}`;
        console.log(`Testing Proxy URL: ${proxyUrl}`);

        try {
            const res = await axios.get(proxyUrl, { responseType: 'arraybuffer' });
            console.log(`✅ Proxy Status: ${res.status}`);
            console.log(`✅ Key Length: ${res.data.length} bytes`);

            // Standard AES-128 key is 16 bytes
            if (res.data.length === 16) {
                console.log("✅ Key seems valid (16 bytes).");
            } else {
                console.log("⚠️ WARNING: Key length is unexpected (not 16 bytes).");
                console.log("Body preview (hex):", res.data.toString('hex'));
            }

        } catch (e: any) {
            console.log(`❌ Proxy Failed: ${e.message}`);
            if (e.response) {
                console.log(`Status: ${e.response.status}`);
                console.log(`Data: ${e.response.data.toString()}`);
            }
        }

    } catch (e) {
        console.error(e);
    }
}

main();
