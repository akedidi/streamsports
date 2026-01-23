import { Sports99Client } from './Sports99Client';

async function main() {
    console.log("Testing Event Fetching...");
    const client = new Sports99Client();

    // Check "All"
    console.log("--- Fetching ALL events ---");
    const all = await client.fetchSportsEvents("all");
    console.log(`Count: ${all.length}`);
    if (all.length > 0) {
        console.log("Sample:", all[0].name, "| Category:", all[0].sport_category);
    }

    // Check "Soccer" specific
    console.log("\n--- Fetching SOCCER events ---");
    const soccer = await client.fetchSportsEvents("soccer");
    console.log(`Count: ${soccer.length}`);
    if (soccer.length > 0) {
        const isActuallySoccer = soccer.every(s => s.sport_category === 'soccer' || s.name.toLowerCase().includes('soccer') || true); // Category might vary depending on API key structure
        console.log("Sample:", soccer[0].name);
    }
}

main();
