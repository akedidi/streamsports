import axios from 'axios';

async function main() {
    console.log("Fetching: http://localhost:3000/api/events?sport=all");
    try {
        const res = await axios.get('http://localhost:3000/api/events?sport=all');
        const events = res.data.events;

        const soccer = events.find((e: any) => e.sport_category.toLowerCase() === 'soccer');
        const nhl = events.find((e: any) => e.sport_category.toLowerCase() === 'nhl');

        console.log("\n--- SOCCER SAMPLE ---");
        if (soccer) {
            console.log(JSON.stringify(soccer, null, 2));
        } else {
            console.log("NO SOCCER EVENTS FOUND.");
        }

        console.log("\n--- NHL SAMPLE ---");
        if (nhl) {
            console.log(JSON.stringify(nhl, null, 2));
        } else {
            console.log("NO NHL EVENTS FOUND.");
        }

    } catch (e: any) {
        console.error("Error:", e.message);
    }
}

main();
