import { Sports99Client } from './Sports99Client';
import axios from 'axios';

async function main() {
    console.log("Debugging 'All Sports' API response...");

    // We want to hit the base /events/sports/ endpoint
    // I'll replicate the construction manually here to inspect raw data easily
    // or just use the client if I can trust it to minimally work.
    // Let's use axios directly to see RAW data first.

    const user = "streamsports99";
    const plan = "vip";
    const url = `https://api.cdn-live.tv/api/v1/events/sports/?user=${user}&plan=${plan}`;

    try {
        const res = await axios.get(url);
        const data = res.data;

        console.log("Root keys:", Object.keys(data));

        if (data["cdn-live-tv"]) {
            console.log("Keys under 'cdn-live-tv':", Object.keys(data["cdn-live-tv"]));

            // Check sample content of one key
            const firstKey = Object.keys(data["cdn-live-tv"])[0];
            const content = data["cdn-live-tv"][firstKey];
            console.log(`Type of content under '${firstKey}':`, Array.isArray(content) ? "Array" : typeof content);
            if (Array.isArray(content)) {
                console.log(`Length: ${content.length}`);
                if (content.length > 0) console.log("Sample item:", content[0]);
            } else {
                console.log("Content preview:", content);
            }
        }

    } catch (e: any) {
        console.error("Error:", e.message);
    }
}

main();
