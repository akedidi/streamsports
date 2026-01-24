import { Sports99Client } from './Sports99Client';
import axios from 'axios';

const client = new Sports99Client();

async function debugRawChannels() {
    const url = `https://api.cdn-live.tv/api/v1/channels/?user=streamsports99&plan=vip`;
    try {
        console.log("Fetching raw channels...");
        const res = await axios.get(url);
        const channels = res.data.channels || [];

        if (channels.length > 0) {
            console.log("First channel raw data:", JSON.stringify(channels[0], null, 2));
            console.log("Sample countries found:");
            const countries = channels.map((c: any) => c.country || c.category).slice(0, 10);
            console.log(countries);
        } else {
            console.log("No channels found.");
        }
    } catch (e) {
        console.error(e);
    }
}

debugRawChannels();
