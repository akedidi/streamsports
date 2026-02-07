import axios from 'axios';
import fs from 'fs';
import { execSync } from 'child_process';

const proxies = [
    "https://corsproxy.io/?",
    "https://cors.eu.org/",
    "https://api.allorigins.win/raw?url=",
    "https://thingproxy.freeboard.io/fetch/",
    "https://cors-anywhere.herokuapp.com/",
    "https://cors.bridged.cc/",
    "https://api.codetabs.com/v1/proxy?quest=",
    "https://yacdn.org/proxy/",
    "https://api.allorigins.win/get?url=",
    "https://crossorigin.me/",
    "https://cors-proxy.htmldriven.com/?url=",
    "https://proxy.cors.sh/",
    "https://cors.is/",
    "https://cors-proxy.fringe.zone/",
    "https://cors.zme.ink/",
    "https://cors.1m.to/",
    "https://cors.kurnia.dev/"
];

async function getFreshStreamUrl(): Promise<string | null> {
    console.log("Fetching fresh stream URL...");
    try {
        execSync(`curl -sS -H "User-Agent: Mozilla/5.0 Chrome/120" -H "Referer: https://streamsports99.su/" "https://cdn-live.tv/api/v1/channels/player/?name=nbc&code=us&user=cdnlivetv&plan=free" > /tmp/player_proxy_test.html`);

        const output = execSync('npx ts-node debug_pattern.ts').toString();
        const lines = output.split('\n');
        const urlLine = lines.find(l => l.includes('https://edge.cdn-live.ru'));

        return urlLine ? urlLine.trim() : null;
    } catch (e: any) {
        console.error("Setup incorrect:", e.message);
        return null;
    }
}

async function testProxies() {
    const url = await getFreshStreamUrl();
    if (!url) {
        console.error("❌ Aborting: No valid stream URL to test.");
        return;
    }

    console.log(`\nTesting ${proxies.length} proxies with URL: ${url.substring(0, 50)}...`);

    const results: any[] = [];

    for (const proxyBase of proxies) {
        const testUrl = `${proxyBase}${encodeURIComponent(url)}`;
        const start = Date.now();
        console.log(`\n--- Testing ${proxyBase} ---`);

        try {
            const controller = new AbortController();
            const timeout = setTimeout(() => controller.abort(), 8000);

            const res = await axios.get(testUrl, {
                signal: controller.signal,
                validateStatus: () => true,
                headers: {
                    'Origin': 'https://cdn-live.tv',
                    'Referer': 'https://cdn-live.tv/'
                }
            });
            clearTimeout(timeout);

            const duration = Date.now() - start;
            console.log(`Status: ${res.status}`);

            let status: string | number = res.status;
            if (res.status === 200) {
                const dataStr = typeof res.data === 'string' ? res.data : JSON.stringify(res.data);
                if (dataStr.includes('#EXTM3U')) {
                    status = '✅ WORKING';
                } else {
                    status = '⚠️ 200 OK (Invalid Content)';
                }
            }

            results.push({ proxy: proxyBase, status, duration });

        } catch (e: any) {
            const duration = Date.now() - start;
            console.log(`Error: ${e.message}`);
            results.push({ proxy: proxyBase, status: `ERROR: ${e.message}`, duration });
        }
    }

    console.log("\n\n=== SUMMARY ===");
    console.table(results);
}

testProxies();
