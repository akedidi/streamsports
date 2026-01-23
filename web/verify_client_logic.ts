import { Sports99Client } from './Sports99Client';

async function main() {
    console.log("Verifying Client Logic...");
    const client = new Sports99Client();

    try {
        console.log("Fetching 'all' sports...");
        const all = await client.fetchSportsEvents("all");
        console.log(`Result Count: ${all.length}`);

        if (all.length === 0) {
            console.error("FAIL: Returned 0 events. Logic might still be broken.");
        } else {
            console.log("SUCCESS: Events found.");
            // Check sample names
            const sample = all.find(e => !e.name.includes("undefined"));
            if (sample) {
                console.log(`Valid Sample: ${sample.name} [${sample.sport_category}]`);
            } else {
                console.log("WARN: Events found but names look bad?", all[0].name);
            }

            // Check for NHL or generic if possible
            const nhl = all.find(e => e.sport_category.toLowerCase() === 'nhl');
            if (nhl) {
                console.log(`NHL Sample: ${nhl.name}`);
            }
        }
    } catch (e: any) {
        console.error("CRASH:", e.message);
    }
}

main();
