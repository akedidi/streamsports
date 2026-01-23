import { Sports99Client } from './Sports99Client';

async function main() {
    console.log("Initializing Sports99Client...");
    const client = new Sports99Client();

    console.log("Fetching all channels...");
    try {
        const channels = await client.getAllChannels();
        console.log(`\nFound ${channels.length} total channels.`);

        const sportsChannels = channels.filter(c => c.sport_category);
        const liveTvChannels = channels.filter(c => !c.sport_category);

        console.log(`- Sports Events: ${sportsChannels.length}`);
        console.log(`- Live TV Channels: ${liveTvChannels.length}`);

        if (channels.length > 0) {
            console.log("\n--- First 5 Channels ---");
            channels.slice(0, 5).forEach(c => {
                const type = c.sport_category ? `[${c.sport_category}]` : '[LiveTV]';
                console.log(`${type} ${c.name} | URL: ${c.url}`);
            });

            // Find a channel with a URL to test resolution
            // Prefer a sports event first as they are often the primary use case
            const channelToTest = channels.find(c => c.url && c.url.startsWith('http'));

            if (channelToTest) {
                console.log(`\n--- Testing Stream Resolution ---`);
                console.log(`Target: ${channelToTest.name}`);
                console.log(`Player URL: ${channelToTest.url}`);

                const streamUrl = await client.resolveStreamUrl(channelToTest.url);

                if (streamUrl) {
                    console.log(`✅ SUCCESS: Resolved Stream URL:`);
                    console.log(streamUrl);
                } else {
                    console.log(`❌ FAILURE: Could not resolve stream URL.`);
                }
            } else {
                console.log("\nNo testable channel URL found (all missing or invalid).");
            }
        } else {
            console.log("\nNo channels found to test.");
        }
    } catch (e) {
        console.error("Error in main execution:", e);
    }
}

main();
