import { Sports99Client } from './Sports99Client';
import axios from 'axios';
import { URL } from 'url';

async function main() {
    const client = new Sports99Client();
    const channels = await client.getAllChannels();
    const channel = channels.find(c => c.name.toLowerCase().includes('abc'));
    if (!channel) return;
    const streamUrl = await client.resolveStreamUrl(channel.url);
    if (!streamUrl) return;

    const headers = {
        'Referer': channel.url,
        'Origin': new URL(channel.url).origin,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    };

    try {
        const res = await axios.get(streamUrl, { headers });
        console.log(`URL: ${streamUrl}`);
        console.log(`Status: ${res.status}`);
        console.log(`Content-Type: ${res.headers['content-type']}`);

        const content = res.data;
        console.log(`Starts with #EXTM3U: ${content.toString().startsWith('#EXTM3U')}`);

    } catch (e: any) {
        console.error(e.message);
    }
}

main();
