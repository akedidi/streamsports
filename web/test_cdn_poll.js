const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());
const axios = require('axios');

async function main() {
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();

    await page.setExtraHTTPHeaders({
        'Referer': 'https://cdn-live.tv/',
    });

    await page.setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1");

    let m3u8Url = null;
    let cookieStr = null;

    page.on('request', req => {
        if (req.url().includes('m3u8')) {
            m3u8Url = req.url();
            console.log("\n[!] Found M3U8:", m3u8Url);
        }
    });

    console.log("Navigating to player...");
    await page.goto('https://cdn-live.tv/api/v1/channels/player/?name=abc&code=us&user=cdnlivetv&plan=free', { waitUntil: 'networkidle2' });

    const cookies = await page.cookies();
    cookieStr = cookies.map(c => `${c.name}=${c.value}`).join('; ');
    console.log("[!] Cookies:", cookieStr);

    await browser.close();

    if (!m3u8Url) {
        console.error("Failed to find M3U8");
        return;
    }

    console.log("\nStarting to poll M3U8 every 6 seconds for 3 minutes...");

    const headers = {
        "Cookie": cookieStr,
        "Origin": "https://cdn-live.tv",
        "Referer": "https://cdn-live.tv/",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
        "Pragma": "no-cache",
        "Cache-Control": "no-cache"
    };

    let previousSeq = -1;
    let stuckCount = 0;

    const interval = setInterval(async () => {
        try {
            const res = await axios.get(m3u8Url, { headers });
            const match = res.data.match(/#EXT-X-MEDIA-SEQUENCE:(\d+)/);
            if (match) {
                const seq = parseInt(match[1]);
                if (seq === previousSeq) {
                    stuckCount++;
                    console.log(`[${new Date().toISOString()}] Warning: Sequence stuck at ${seq} for ${stuckCount * 6} seconds!`);
                    if (stuckCount > 25) {
                        console.log("Stream completely stalled for >2 mins... Exiting.");
                        clearInterval(interval);
                    }
                } else {
                    stuckCount = 0;
                    console.log(`[${new Date().toISOString()}] Sequence updated to: ${seq} (+${seq - previousSeq})`);
                    previousSeq = seq;
                }
            } else {
                console.log("No sequence found??");
            }
        } catch (e) {
            console.error(`[${new Date().toISOString()}] Error fetching: ${e.response ? e.response.status : e.message}`);
        }
    }, 6000);
}

main();
