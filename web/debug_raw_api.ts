// Native fetch in Node 18+
async function main() {
    const url = "https://api.cdn-live.tv/api/v1/events/sports/soccer/?user=cdnlivetv&plan=free";
    console.log(`Fetching from ${url}...`);
    try {
        const response = await fetch(url);
        const data = await response.json();
        // The API returns { "data": [...] } or standard list? Previous code assumed data.events
        // Let's inspect the structure first
        console.log("Root keys:", Object.keys(data));

        const root = data['cdn-live-tv'];
        console.log("Root keys:", Object.keys(data));
        console.log("Keys inside 'cdn-live-tv':", Object.keys(root));

        // Found 'Soccer' key in previous output
        let events = root.Soccer || [];

        console.log(`Found ${events.length} events.`);
        if (events.length > 0) {
            console.log("Sample Event Keys:", Object.keys(events[0]));
            if (events[0].end) {
                console.log("Found 'end' field example:", events[0].end);
            } else {
                console.log("'end' field NOT found in first event (sample):", JSON.stringify(events[0], null, 2));
            }
            // Check a few more just in case
            events.slice(0, 5).forEach((e, i) => {
                console.log(`Event ${i}: start=${e.start}, end=${e.end || 'N/A'}`);
            });
        }
    } catch (error) {
        console.error("Error fetching API:", error);
    }
}

main();
