const { execSync } = require('child_process');
const axios = require('axios');

async function getStreamApi() {
    const res = await axios.get("https://streamsports-wine.vercel.app/api/proxy?url=https://cdn-live.tv/api/v1/channels/player/?name=abc&code=us&user=cdnlivetv&plan=free&force_proxy=true&referer=https://cdn-live.tv/&cookie=1");
    return res.data; 
}

async function run() {
    console.log("Fetching stream...");
    // Let's just use the python script or curl? Actually we need to extract the m3u8.
    // We already have a python script `resolve_cdn.py` or similar? Let's write a quick puppeteer script or just use the backend proxy.
}

run();
