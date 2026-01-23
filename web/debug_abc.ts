import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    try {
        console.log("Fetching channels...");
        const channels = await client.getAllChannels();

        // Find ABC channels
        const abcChannels = channels.filter(c => c.name.toLowerCase().includes('abc') && !c.name.toLowerCase().includes('barc')); // Exclude barca?

        if (abcChannels.length === 0) {
            console.log("❌ No channel 'ABC' found.");
            return;
        }

        console.log(`Found ${abcChannels.length} channels matching "ABC".`);

        for (const channel of abcChannels) {
            console.log(`\n--------------------------------------------`);
            console.log(`Testing Channel: ${channel.name} (${channel.code})`);
            console.log(`URL: ${channel.url}`);

            try {
                const streamUrl = await client.resolveStreamUrl(channel.url);
                if (streamUrl) {
                    console.log(`✅ Resolved Stream URL: ${streamUrl}`);

                    // Test M3U8 Access
                    const headers = {
                        'Referer': channel.url,
                        'Origin': new URL(channel.url).origin,
                        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                    };

                    try {
                        const res = await axios.get(streamUrl, { headers });
                        console.log(`✅ Playlist fetched (Status: ${res.status}, Length: ${res.data.length})`);
                        if (res.data.includes("EXTM3U")) {
                            console.log("✅ Content looks like a valid M3U8.");
                        } else {
                            console.log("⚠️ Content does not look like M3U8.");
                        }

                    } catch (e: any) {
                        console.log(`❌ Playlist fetch failed: ${e.message} (Status: ${e.response?.status})`);
                    }

                } else {
                    console.log(`❌ Failed to resolve stream URL (null returned).`);
                }
            } catch (error: any) {
                console.log(`❌ Error during resolution: ${error.message}`);
            }
        }

    } catch (e) {
        console.error(e);
    }
}

main();
