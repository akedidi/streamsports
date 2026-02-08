import axios from 'axios';

// List of public CORS/HTTP proxy services to test
const PROXY_SERVICES = [
    { name: 'corsproxy.io', buildUrl: (url: string) => `https://corsproxy.io/?${encodeURIComponent(url)}` },
    { name: 'allorigins.win', buildUrl: (url: string) => `https://api.allorigins.win/raw?url=${encodeURIComponent(url)}` },
    { name: 'codetabs', buildUrl: (url: string) => `https://api.codetabs.com/v1/proxy?quest=${encodeURIComponent(url)}` },
    { name: 'thingproxy', buildUrl: (url: string) => `https://thingproxy.freeboard.io/fetch/${url}` },
    { name: 'cors-anywhere-herokuapp', buildUrl: (url: string) => `https://cors-anywhere.herokuapp.com/${url}` },
    { name: 'crossorigin.me', buildUrl: (url: string) => `https://crossorigin.me/${url}` },
    { name: 'cors.bridged.cc', buildUrl: (url: string) => `https://cors.bridged.cc/${url}` },
    { name: 'yacdn.org', buildUrl: (url: string) => `https://yacdn.org/proxy/${url}` },
    { name: 'cors-proxy.htmldriven', buildUrl: (url: string) => `https://cors-proxy.htmldriven.com/?url=${encodeURIComponent(url)}` },
    { name: 'gobetween.oklabs', buildUrl: (url: string) => `https://gobetween.oklabs.org/${url}` },
    { name: 'jsonp.afeld.me', buildUrl: (url: string) => `https://jsonp.afeld.me/?url=${encodeURIComponent(url)}` },
    { name: 'alloworigin.com', buildUrl: (url: string) => `https://alloworigin.com/get?url=${encodeURIComponent(url)}` },
    { name: 'cors.sh', buildUrl: (url: string) => `https://cors.sh/${url}` },
    { name: 'proxy.cors.sh', buildUrl: (url: string) => `https://proxy.cors.sh/${url}` },
    { name: 'corsproxy.github.io', buildUrl: (url: string) => `https://corsproxy.github.io/?${encodeURIComponent(url)}` },
    { name: 'api.scraperbox', buildUrl: (url: string) => `https://api.scraperbox.com/scrape?url=${encodeURIComponent(url)}` },
    { name: 'cors-proxy.taskcluster', buildUrl: (url: string) => `https://cors-proxy.taskcluster.net/request?url=${encodeURIComponent(url)}` },
    { name: 'corsproxy.org', buildUrl: (url: string) => `https://corsproxy.org/?${encodeURIComponent(url)}` },
    { name: 'api.webscraping.ai', buildUrl: (url: string) => `https://api.webscraping.ai/html?url=${encodeURIComponent(url)}` },
    { name: 'proxysite.cloud', buildUrl: (url: string) => `https://proxysite.cloud/fetch?url=${encodeURIComponent(url)}` },
    { name: 'bypass-cors.herokuapp', buildUrl: (url: string) => `https://bypass-cors.herokuapp.com/${url}` },
    { name: 'nocors.vercel.app', buildUrl: (url: string) => `https://nocors.vercel.app/api?url=${encodeURIComponent(url)}` },
    { name: 'proxy-any.vercel.app', buildUrl: (url: string) => `https://proxy-any.vercel.app/api/proxy?url=${encodeURIComponent(url)}` },
    { name: 'cors-anywhere-deno', buildUrl: (url: string) => `https://cors-anywhere.deno.dev/${url}` },
    { name: 'corsfix.com', buildUrl: (url: string) => `https://corsfix.com/?${encodeURIComponent(url)}` },
    { name: 'corsmirror.com', buildUrl: (url: string) => `https://corsmirror.com/v1/cors?url=${encodeURIComponent(url)}` },
    { name: 'cors.eu.org', buildUrl: (url: string) => `https://cors.eu.org/${url}` },
    { name: 'corsproxy.net', buildUrl: (url: string) => `https://corsproxy.net/${url}` },
    { name: 'api.proxycrawl', buildUrl: (url: string) => `https://api.crawlbase.com/?url=${encodeURIComponent(url)}` },
    { name: 'cloudflare-cors-anywhere', buildUrl: (url: string) => `https://test.cors.workers.dev/?${encodeURIComponent(url)}` },
];

const HEADERS = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
};

interface TestResult {
    name: string;
    success: boolean;
    status?: number;
    error?: string;
    responseTime?: number;
    hasM3U8Content?: boolean;
}

async function testProxy(
    proxy: { name: string; buildUrl: (url: string) => string },
    targetUrl: string,
    cookie?: string
): Promise<TestResult> {
    const startTime = Date.now();
    const proxyUrl = proxy.buildUrl(targetUrl);

    try {
        const headers: any = { ...HEADERS };
        if (cookie) {
            headers['Cookie'] = cookie;
        }
        headers['X-Requested-With'] = 'XMLHttpRequest';
        headers['Referer'] = 'https://cdn-live.tv/';
        headers['Origin'] = 'https://cdn-live.tv';

        const response = await axios.get(proxyUrl, {
            headers,
            timeout: 15000,
            validateStatus: () => true,
        });

        const responseTime = Date.now() - startTime;
        const isM3U8 = typeof response.data === 'string' && response.data.includes('#EXTM3U');

        return {
            name: proxy.name,
            success: response.status === 200 && isM3U8,
            status: response.status,
            responseTime,
            hasM3U8Content: isM3U8,
        };
    } catch (error: any) {
        return {
            name: proxy.name,
            success: false,
            error: error.code || error.message,
            responseTime: Date.now() - startTime,
        };
    }
}

async function main() {
    console.log('🔍 Starting Proxy Test Suite\n');
    console.log('='.repeat(60));

    // Step 1: Resolve a test stream URL via deployed API
    console.log('\n📡 Resolving test stream URL via Vercel API...');
    const testPlayerUrl = 'https://cdn-live.tv/api/v1/channels/player/?name=abc&code=us&user=cdnlivetv&plan=free';

    let targetUrl: string;
    let cookie: string | undefined;

    try {
        const apiUrl = `https://streamsports-wine.vercel.app/api/stream?url=${encodeURIComponent(testPlayerUrl)}`;
        const apiResponse = await axios.get(apiUrl, { timeout: 30000 });

        if (!apiResponse.data.success || !apiResponse.data.rawUrl) {
            console.error('❌ Failed to resolve stream URL from API');
            process.exit(1);
        }

        targetUrl = apiResponse.data.rawUrl;

        // Extract cookie from streamUrl query params
        const streamUrlParams = new URLSearchParams(apiResponse.data.streamUrl.split('?')[1]);
        cookie = streamUrlParams.get('cookie') || undefined;
        if (cookie) cookie = decodeURIComponent(cookie);

        console.log(`✅ Stream URL: ${targetUrl.substring(0, 80)}...`);
        console.log(`🍪 Cookie: ${cookie || 'None'}`);
    } catch (error: any) {
        console.error(`❌ Failed to resolve stream URL: ${error.message}`);
        process.exit(1);
    }

    console.log('\n' + '='.repeat(60));
    console.log(`\n🧪 Testing ${PROXY_SERVICES.length} proxy services...\n`);

    // Step 2: Test each proxy
    const results: TestResult[] = [];

    for (const proxy of PROXY_SERVICES) {
        process.stdout.write(`  Testing ${proxy.name.padEnd(30)}... `);
        const testResult = await testProxy(proxy, targetUrl, cookie);
        results.push(testResult);

        if (testResult.success) {
            console.log(`✅ OK (${testResult.responseTime}ms)`);
        } else if (testResult.status === 401) {
            console.log(`🔒 401 Unauthorized (${testResult.responseTime}ms)`);
        } else if (testResult.status === 403) {
            console.log(`🚫 403 Forbidden (${testResult.responseTime}ms)`);
        } else if (testResult.error) {
            console.log(`❌ Error: ${testResult.error}`);
        } else {
            console.log(`⚠️  Status ${testResult.status} (${testResult.responseTime}ms)`);
        }
    }

    // Step 3: Summary
    console.log('\n' + '='.repeat(60));
    console.log('\n📊 Summary:\n');

    const working = results.filter(r => r.success);
    const unauthorized = results.filter(r => r.status === 401);
    const forbidden = results.filter(r => r.status === 403);
    const errors = results.filter(r => r.error);
    const other = results.filter(r => !r.success && !r.error && r.status !== 401 && r.status !== 403);

    console.log(`  ✅ Working:      ${working.length}`);
    console.log(`  🔒 Unauthorized: ${unauthorized.length}`);
    console.log(`  🚫 Forbidden:    ${forbidden.length}`);
    console.log(`  ❌ Errors:       ${errors.length}`);
    console.log(`  ⚠️  Other:        ${other.length}`);

    if (working.length > 0) {
        console.log('\n🎉 Working proxies:');
        working.forEach(r => {
            console.log(`    - ${r.name} (${r.responseTime}ms)`);
        });
    } else {
        console.log('\n😔 No working proxies found.');
        console.log('   This likely means the stream requires IP-bound sessions.');
    }

    // Also test direct request (no proxy)
    console.log('\n' + '='.repeat(60));
    console.log('\n🔬 Testing DIRECT request (no proxy)...\n');

    try {
        const headers: any = { ...HEADERS };
        if (cookie) headers['Cookie'] = cookie;
        headers['Referer'] = 'https://cdn-live.tv/';

        const directResponse = await axios.get(targetUrl, {
            headers,
            timeout: 15000,
            validateStatus: () => true,
        });

        const isM3U8 = typeof directResponse.data === 'string' && directResponse.data.includes('#EXTM3U');

        if (directResponse.status === 200 && isM3U8) {
            console.log(`  ✅ DIRECT works! Status: ${directResponse.status}`);
            console.log(`     The issue is likely IP-based session binding.`);
            console.log(`     Your current machine IP can access the stream.`);
        } else {
            console.log(`  ⚠️  DIRECT Status: ${directResponse.status}, M3U8: ${isM3U8}`);
        }
    } catch (error: any) {
        console.log(`  ❌ DIRECT Error: ${error.code || error.message}`);
    }

    console.log('\n' + '='.repeat(60));
    console.log('Done!');
}

main().catch(console.error);
