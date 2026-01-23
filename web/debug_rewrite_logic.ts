import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();

    // 1. Get ABC URL
    const channels = await client.getAllChannels();
    const channel = channels.find(c => c.name.toLowerCase().includes('abc') && !c.name.toLowerCase().includes('barc'));
    if (!channel) return;
    const streamUrl = await client.resolveStreamUrl(channel.url);
    if (!streamUrl) return;

    console.log(`Base URL: ${streamUrl}`);
    const baseUrl = streamUrl.substring(0, streamUrl.lastIndexOf('/') + 1);
    console.log(`Derived Base: ${baseUrl}`);

    // 2. Fetch Playlist
    const headers = {
        'Referer': channel.url,
        'Origin': new URL(channel.url).origin,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    };
    const res = await axios.get(streamUrl, { headers });
    const m3u8Content = res.data;

    console.log("\n--- REWRITE SIMULATION ---");

    const lines = m3u8Content.split('\n');
    lines.forEach((line: string) => {
        const trimmed = line.trim();

        // This is the logic from server.ts
        if (trimmed && !trimmed.startsWith('#')) {
            console.log(`[FOUND LINE]: ${trimmed}`);

            let absoluteUrl = trimmed;
            if (!trimmed.startsWith('http')) {
                absoluteUrl = new URL(trimmed, baseUrl).toString();
                console.log(`   -> Resolved Relative: ${absoluteUrl}`);
            }

            if (absoluteUrl.includes('.m3u8')) {
                const proxied = `/api/proxy?url=${encodeURIComponent(absoluteUrl)}`;
                console.log(`   -> Rewritten (Proxy): ${proxied}`);
            } else {
                console.log(`   -> Rewritten (Direct): ${absoluteUrl}`);
            }
        }
    });
}

main();
