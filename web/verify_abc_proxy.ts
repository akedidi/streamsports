import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    console.log("Resolving ABC...");
    const channels = await client.getAllChannels();
    const channel = channels.find(c => c.name.toLowerCase().includes('abc') && !c.name.toLowerCase().includes('barc'));
    if (!channel) return;
    const streamUrl = await client.resolveStreamUrl(channel.url);
    if (!streamUrl) return;

    // Construct Proxy URL
    const proxyUrl = `http://localhost:3000/api/proxy?url=${encodeURIComponent(streamUrl)}&referer=${encodeURIComponent(channel.url)}`;
    console.log(`Checking Proxy: ${proxyUrl}`);

    try {
        const res = await axios.get(proxyUrl);
        const body = res.data;

        console.log("--- PROXY RESPONSE CHECK ---");

        // Check for specific problematic path
        if (body.includes("tracks-v1a1") || body.includes("tracks-a1")) {
            const lines = body.split('\n');
            let failure = false;

            lines.forEach((line: string) => {
                if ((line.includes("tracks-v1a1") || line.includes("tracks-a1"))) {
                    if (!line.includes("/api/proxy?url=")) {
                        console.log(`❌ FAIL: Unproxied Line: ${line}`);
                        failure = true;
                    } else {
                        console.log(`✅ OK: Proxied Line: ${line.substring(0, 50)}...`);
                    }
                }
            });

            if (!failure) {
                console.log("\n>>> VERDICT: SUCCESS. All relative paths are rewritten.");
            } else {
                console.log("\n>>> VERDICT: FAIL. Some relative paths missed.");
            }
        } else {
            console.log("\n>>> VERDICT: SUCCESS (Clean).");
        }

    } catch (e: any) {
        console.error("Proxy Request Failed:", e.message);
    }
}

main();
