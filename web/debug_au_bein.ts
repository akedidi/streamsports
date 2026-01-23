import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    try {
        console.log("Fetching channels...");
        const channels = await client.getAllChannels();

        // 1. Search for AU beIN Sports 1
        console.log("\n--- Searching for 'AU beIN Sports 1' ---");
        const auBein = channels.find(c =>
            c.name.toLowerCase().includes('bein') &&
            c.code?.toLowerCase() === 'au'
        );

        if (auBein) {
            await testChannel(client, auBein);
        } else {
            console.log("❌ 'AU beIN Sports 1' NOT FOUND.");
        }

        // 2. Search for BTN (Big Ten Network) - matching user's URL log
        console.log("\n--- Searching for 'BTN' (Big Ten Network) ---");
        const btn = channels.find(c => c.name.toLowerCase() === 'btn' || (c.name.toLowerCase().includes('btn') && c.code === 'us'));

        if (btn) {
            await testChannel(client, btn);
        } else {
            console.log("❌ 'BTN' NOT FOUND.");
        }

    } catch (e) {
        console.error(e);
    }
}

async function testChannel(client: Sports99Client, channel: any) {
    console.log(`Testing Channel: ${channel.name} (${channel.code})`);
    console.log(`URL: ${channel.url}`);

    const streamUrl = await client.resolveStreamUrl(channel.url);
    if (!streamUrl) {
        console.log("❌ Resolution returned null.");
        return;
    }
    console.log(`Resolved URL: ${streamUrl}`);

    const headers = {
        'Referer': channel.url,
        'Origin': new URL(channel.url).origin,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    };

    try {
        await axios.get(streamUrl, { headers });
        console.log("✅ Playlist fetched successfully (200 OK).");
    } catch (e: any) {
        console.log(`❌ Playlist fetch failed: ${e.message}`);
        if (e.response) console.log(`Status: ${e.response.status}`);
    }
}

main();
