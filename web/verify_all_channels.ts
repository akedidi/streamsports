import { Sports99Client, Sports99Channel } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';
import fs from 'fs';

interface ChannelStatus {
    name: string;
    code: string;
    status: 'OK' | 'FAILED';
    stage: 'RESOLUTION' | 'PLAYLIST' | 'KEY_PROXY' | 'SEGMENT';
    error?: string;
    encrypted: boolean;
}

const CONCURRENT_BATCH_SIZE = 20;

async function verifyChannel(client: Sports99Client, channel: Sports99Channel): Promise<ChannelStatus> {
    const status: ChannelStatus = {
        name: channel.name,
        code: channel.code || 'unknown',
        status: 'FAILED',
        stage: 'RESOLUTION',
        encrypted: false
    };

    try {
        // 1. Resolve
        if (!channel.url) {
            status.error = "No URL provided";
            return status;
        }
        const result = await client.resolveStreamUrl(channel.url);
        if (!result || !result.streamUrl) {
            status.error = "Resolution returned null";
            return status;
        }

        // 2. Playlist Access
        status.stage = 'PLAYLIST';
        const streamUrl = result!.streamUrl;
        const headers = {
            'Referer': channel.url,
            'Origin': new URL(channel.url).origin,
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        };

        const masterRes = await axios.get(streamUrl, { headers, timeout: 5000 });

        let mediaUrl = streamUrl;
        let playlistContent = masterRes.data;

        // If Master, find Media
        if (masterRes.data.includes('#EXT-X-STREAM-INF')) {
            const lines = masterRes.data.split('\n');
            const foundLine = lines.find((l: string) => l.trim() && !l.startsWith('#'));
            if (foundLine) {
                let foundUrl = foundLine.trim();
                if (!foundUrl.startsWith('http')) {
                    mediaUrl = new URL(foundUrl, streamUrl.substring(0, streamUrl.lastIndexOf('/') + 1)).toString();
                } else {
                    mediaUrl = foundUrl;
                }
                const mediaRes = await axios.get(mediaUrl, { headers, timeout: 5000 });
                playlistContent = mediaRes.data;
            }
        }

        // 3. Check for Keys
        const keyMatch = playlistContent.match(/URI="([^"]+)"/);
        if (keyMatch) {
            status.encrypted = true;
            status.stage = 'KEY_PROXY';

            let keyUrl = keyMatch[1];
            if (!keyUrl.startsWith('http')) {
                keyUrl = new URL(keyUrl, mediaUrl.substring(0, mediaUrl.lastIndexOf('/') + 1)).toString();
            }

            // Test Proxy Access for Key
            const proxyUrl = `http://localhost:3000/api/proxy?url=${encodeURIComponent(keyUrl)}&referer=${encodeURIComponent(channel.url)}`;
            try {
                await axios.get(proxyUrl, { timeout: 5000 });
            } catch (proxyErr: any) {
                status.error = `Key Proxy Failed: ${proxyErr.message}`;
                return status;
            }
        }

        status.status = 'OK';
        return status;

    } catch (e: any) {
        status.error = e.message;
        return status;
    }
}

async function main() {
    console.log("Starting Comprehensive Channel Verification...");
    const client = new Sports99Client();

    try {
        const channels = await client.getAllChannels();
        console.log(`Total Channels to Verify: ${channels.length}`);

        const results: ChannelStatus[] = [];

        for (let i = 0; i < channels.length; i += CONCURRENT_BATCH_SIZE) {
            const batch = channels.slice(i, i + CONCURRENT_BATCH_SIZE);
            console.log(`Processing batch ${i + 1} - ${Math.min(i + CONCURRENT_BATCH_SIZE, channels.length)}...`);

            const batchResults = await Promise.all(batch.map(c => verifyChannel(client, c)));
            results.push(...batchResults);
        }

        // Summary
        const passed = results.filter(r => r.status === 'OK');
        const failed = results.filter(r => r.status === 'FAILED');
        const encrypted = results.filter(r => r.encrypted);

        console.log("\n------------------------------------------------");
        console.log("VERIFICATION COMPLETE");
        console.log("------------------------------------------------");
        console.log(`Total: ${results.length}`);
        console.log(`✅ Passed: ${passed.length} (${((passed.length / results.length) * 100).toFixed(1)}%)`);
        console.log(`❌ Failed: ${failed.length}`);
        console.log(`🔒 Encrypted Channels: ${encrypted.length}`);
        console.log("------------------------------------------------");

        // Save detailed report
        fs.writeFileSync('verification_report.json', JSON.stringify(results, null, 2));
        console.log("Detailed report saved to 'verification_report.json'");

    } catch (e) {
        console.error("Fatal Error:", e);
    }
}

main();
