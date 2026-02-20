const axios = require('axios');

const url = "https://edge.cdn-live.ru/secure/api/v1/us-abc/playlist.m3u8?token=ca11a168c46c1aee62bfdfc09490d85ad77f86e435abc020d286cd125a25f3e4.1771591141.2b9df7e1ec3084e5221234ada24155a2.9cc44941eb4d3139b2ecba42dacec8f8.57d9803c8352cf07914b3569fa812cb5&signature=5d1915bf6b76164aefaf8d39fbbb10c7b120b527484db41f88dd63d2f61616b8";
const headers = {
    "Cookie": "PHPSESSID=k7fgubhc1cenjvajl4r06820gv",
    "Origin": "https://cdn-live.tv",
    "Referer": "https://cdn-live.tv/",
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
    "Pragma": "no-cache",
    "Cache-Control": "no-cache"
};

let previousSequence = -1;
let unchangedCount = 0;

console.log("Starting test. Will fetch every 6 seconds...");

setInterval(async () => {
    try {
        const response = await axios.get(url, { headers });
        const m3u8 = response.data;

        const seqMatch = m3u8.match(/#EXT-X-MEDIA-SEQUENCE:(\d+)/);
        if (seqMatch) {
            const seq = parseInt(seqMatch[1], 10);
            if (seq === previousSequence) {
                unchangedCount++;
                console.log(`[${new Date().toISOString()}] ⚠️ Sequence UNCHANGED: ${seq} (Stuck for ${unchangedCount * 6}s)`);
            } else {
                unchangedCount = 0;
                console.log(`[${new Date().toISOString()}] ✅ Sequence: ${seq}`);
            }
            previousSequence = seq;
        } else {
            console.log(`[${new Date().toISOString()}] ❌ No Media Sequence found. Start of response:`, m3u8.substring(0, 100));
        }

    } catch (e) {
        if (e.response) {
            console.log(`[${new Date().toISOString()}] ❌ HTTP Error ${e.response.status}:`, e.response.data);
        } else {
            console.log(`[${new Date().toISOString()}] ❌ Error:`, e.message);
        }
    }
}, 6000);
