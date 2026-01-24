import { Sports99Client } from './Sports99Client';

async function main() {
    console.log("Testing Event Fetching...");
    const client = new Sports99Client();

    // Check "All"
    console.log("--- Fetching ALL events ---");
    const all = await client.fetchSportsEvents("all");
    console.log(`Count: ${all.length}`);

    // Check "Live" specific and log timestamps
    console.log("\n--- Fetching LIVE events for Stale Check ---");
    const live = all.filter(e => e.status === "live");
    console.log(`Count: ${live.length} live events`);

    if (live.length > 0) {
        console.log("Sample Live Events:");
        live.slice(0, 50).forEach(e => {
            console.log(`- [${e.gameID}] Time: ${e.time} | Start: ${e.start} | Name: ${e.name}`);
        });
    }
    // Search for Manchester City
    const manCity = all.filter(e =>
        e.name.toLowerCase().includes('manchester') ||
        e.name.toLowerCase().includes('city') ||
        (e.home_team && e.home_team.toLowerCase().includes('manchester')) ||
        (e.away_team && e.away_team.toLowerCase().includes('manchester'))
    );

    console.log(`Found ${manCity.length} events matching 'Manchester':`);
    manCity.forEach(e => {
        console.log(`- ID: ${e.gameID} | MatchInfo: ${e.match_info}`);
        console.log(`  Name: ${e.name}`);
        console.log(`  Time: ${e.time} | Status: ${e.status}`);
    });
}

main();
