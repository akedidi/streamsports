import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    try {
        console.log("Fetching channels...");
        const channels = await client.getAllChannels();
        const channel = channels.find(c => c.url && c.url.startsWith('http'));
        if (!channel) { console.log("No channel found."); return; }

        console.log(`Testing channel: ${channel.name}`);
        const result = await client.resolveStreamUrl(channel.url); const streamUrl = result ? result.streamUrl : null;
        if (!streamUrl) return;

        const headers = {
            'Referer': channel.url,
            'Origin': new URL(channel.url).origin,
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        };

        // 1. Fetch Master
        const masterRes = await axios.get(streamUrl, { headers });
        const masterLines = masterRes.data.split('\n');
        let mediaUrl: string | null = null;
        for (const line of masterLines) {
            if (line && !line.startsWith('#') && line.trim()) {
                mediaUrl = line.trim();
                break;
            }
        }
        if (!mediaUrl!.startsWith('http')) {
            mediaUrl = new URL(mediaUrl!, streamUrl.substring(0, streamUrl.lastIndexOf('/') + 1)).toString();
        }

        // 2. Fetch Media
        const mediaRes = await axios.get(mediaUrl!, { headers });
        const mediaLines = mediaRes.data.split('\n');
        let segmentUrl: string | null = null;
        for (const line of mediaLines) {
            if (line && !line.startsWith('#') && line.trim()) {
                segmentUrl = line.trim();
                break;
            }
        }
        if (!segmentUrl!.startsWith('http')) {
            segmentUrl = new URL(segmentUrl!, mediaUrl!.substring(0, mediaUrl!.lastIndexOf('/') + 1)).toString();
        }

        console.log(`\nTarget Segment: ${segmentUrl}`);

        // 3. Control Test: Fetch WITH Headers
        console.log("3. Control: Fetching WITH valid headers...");
        try {
            await axios.get(segmentUrl!, { headers });
            console.log("✅ Control passed (Segment is valid).");
        } catch (e: any) {
            console.log(`❌ Control FAILED: ${e.message}`);
            return; // If valid headers fail, we can't test further
        }

        // 4. Test Direct Access (Simulation of Browser with Wrong Referer)
        console.log("\n4. Test: Fetching with 'Referer: http://localhost:3000'...");
        try {
            await axios.get(segmentUrl!, {
                headers: {
                    'Referer': 'http://localhost:3000',
                    'Origin': 'http://localhost:3000'
                }
            });
            console.log("✅ SUCCESS: Segment fetched with local Referer!");
            console.log("CONCLUSION: Light Proxy is SAFE.");
        } catch (e: any) {
            console.log(`❌ FAILED: ${e.message} (Status: ${e.response?.status})`);

            // 5. Test Direct Access (NO Referer)
            console.log("5. Test: Fetching with NO Referer...");
            try {
                await axios.get(segmentUrl!);
                console.log("✅ SUCCESS: Segment fetched with NO Referer!");
                console.log("CONCLUSION: Light Proxy needs <meta name=\"referrer\" content=\"no-referrer\">.");
            } catch (e2: any) {
                console.log(`❌ FAILED: ${e2.message} (Status: ${e2.response?.status})`);
                console.log("CONCLUSION: Full Proxy REQUIRED.");
            }
        }

    } catch (e) {
        console.error(e);
    }
}

main();
