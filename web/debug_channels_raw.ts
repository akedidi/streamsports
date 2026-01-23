import { Sports99Client } from './Sports99Client';
import axios from 'axios';

async function main() {
    console.log("Fetching Raw Channel Data...");
    const client = new Sports99Client();

    // We need to access the private method/url structure basically.
    // simpler to just use axios here using the client's constants if we knew them, 
    // but better to just ask the client.

    // Let's modify client to expose raw or just logging it.
    // actually, let's just use the fetchLiveTvChannels and inspect properties.

    const channels = await client.fetchLiveTvChannels();
    if (channels.length > 0) {
        console.log("--- Sample Channel ---");
        console.log(channels[0]);

        // Check for common EPG keys
        const first = channels[0] as any;
        console.log("EPG Keys check:");
        console.log("- current_program:", first.current_program);
        console.log("- playing:", first.playing);
        console.log("- program:", first.program);
        console.log("- description:", first.description);
        console.log("- title:", first.title);
    } else {
        console.log("No channels found.");
    }
}

main();
