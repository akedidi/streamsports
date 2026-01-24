// Debug script to check Liverpool and Marseille events
const fetch = require('node-fetch');

async function debug() {
    const response = await fetch('https://api.cdn-live.tv/api/v1/events/sports/soccer/?user=cdnlivetv&plan=free');
    const data = await response.json();

    const events = data['cdn-live-tv']['Soccer'];

    // Find Liverpool match
    const liverpoolMatch = events.find(e => e.homeTeam === 'Liverpool' || e.awayTeam === 'Liverpool');
    console.log('\n=== LIVERPOOL MATCH ===');
    if (liverpoolMatch) {
        console.log(`GameID: ${liverpoolMatch.gameID}`);
        console.log(`Match: ${liverpoolMatch.homeTeam} vs ${liverpoolMatch.awayTeam}`);
        console.log(`Status: ${liverpoolMatch.status}`);
        console.log(`Channels: ${liverpoolMatch.channels.length}`);
        console.log(`Start: ${liverpoolMatch.start}`);
    } else {
        console.log('Liverpool match not found!');
    }

    // Find Marseille match
    const marseilleMatch = events.find(e => e.homeTeam?.includes('Marseille') || e.awayTeam?.includes('Marseille'));
    console.log('\n=== MARSEILLE MATCH ===');
    if (marseilleMatch) {
        console.log(`GameID: ${marseilleMatch.gameID}`);
        console.log(`Match: ${marseilleMatch.homeTeam} vs ${marseilleMatch.awayTeam}`);
        console.log(`Status: ${marseilleMatch.status}`);
        console.log(`Channels: ${marseilleMatch.channels.length}`);
        console.log(`Start: ${marseilleMatch.start}`);
    } else {
        console.log('Marseille match not found!');
    }
}

debug();
