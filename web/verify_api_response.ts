import axios from 'axios';

async function main() {
    console.log("Testing Running Server API: http://localhost:3000/api/events?sport=all");
    try {
        const res = await axios.get('http://localhost:3000/api/events?sport=all');
        const data = res.data;

        console.log("Success:", data.success);
        console.log("Count:", data.count);

        if (data.events && Array.isArray(data.events)) {
            console.log("Events Array Length:", data.events.length);
            if (data.events.length > 0) {
                console.log("First Event:", data.events[0].name);
                console.log("Last Event:", data.events[data.events.length - 1].name);
            } else {
                console.error("CRITICAL: Events array is EMPTY.");
            }
        } else {
            console.error("CRITICAL: 'events' field is missing or not an array.");
        }
    } catch (e: any) {
        console.error("Connection Failed. Is server running?", e.message);
    }
}

main();
