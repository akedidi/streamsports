import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    try {
        console.log("Fetching channels...");
        const channels = await client.getAllChannels();

        // Find TF1 (Case insensitive)
        const channel = channels.find(c => c.name.toLowerCase().includes('tf1') || c.name.toLowerCase() === 'tf1');

        if (!channel) {
            console.log("❌ Channel 'TF1' not found in the list.");
            return;
        }

        console.log("\n--- Channel Details ---");
        console.log(`Name: ${channel.name}`);
        console.log(`Code (Country?): ${channel.code}`);
        console.log(`URL: ${channel.url}`);
        console.log(`Sport Category: ${channel.sport_category || 'N/A'}`);
        console.log("-----------------------\n");

        console.log(`Resolving stream for: ${channel.name}`);
        const result = await client.resolveStreamUrl(channel.url); const streamUrl = result ? result.streamUrl : null;

        if (result && result.streamUrl) {
            console.log(`✅ Resolved Stream URL:`);
            console.log(streamUrl);

            // Try fetching the M3U8 to check for 403/404
            console.log("\nTesting access to M3U8...");
            try {
                const headers = {
                    'Referer': channel.url,
                    'Origin': new URL(channel.url).origin,
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                };
                await axios.get(streamUrl, { headers });
                console.log("✅ Stream is accessible with correct headers.");
            } catch (e: any) {
                console.log(`❌ Stream access failed: ${e.message}`);
                if (e.response) console.log(`Status: ${e.response.status}`);
            }

        } else {
            console.log(`❌ Failed to resolve stream URL.`);
            console.log("Possible causes: Obfuscation pattern changed, or region block.");
        }

    } catch (e) {
        console.error(e);
    }
}

main();
