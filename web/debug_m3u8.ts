import { Sports99Client } from './Sports99Client';
import axios from 'axios';

async function main() {
    const client = new Sports99Client();
    try {
        console.log("Fetching channels...");
        const channels = await client.getAllChannels();

        // Find a channel with a URL
        const channel = channels.find(c => c.url && c.url.startsWith('http'));
        if (!channel) {
            console.log("No testable channel found.");
            return;
        }

        console.log(`Resolving stream for: ${channel.name}`);
        const result = await client.resolveStreamUrl(channel.url); const streamUrl = result ? result.streamUrl : null;

        if (result && result.streamUrl) {
            console.log(`Resolved URL: ${streamUrl}`);
            console.log("Fetching m3u8 content...");

            try {
                const res = await axios.get(streamUrl, {
                    headers: {
                        'Referer': channel.url,
                        'Origin': new URL(channel.url).origin,
                        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                    }
                });
                console.log("\n--- M3U8 Content Start ---");
                console.log(res.data);
                console.log("--- M3U8 Content End ---\n");
            } catch (e: any) {
                console.error("Error fetching m3u8:", e.message);
            }
        } else {
            console.log("Could not resolve stream URL.");
        }

    } catch (e) {
        console.error(e);
    }
}

main();
