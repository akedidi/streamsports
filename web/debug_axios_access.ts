import { Sports99Client } from './Sports99Client';
import axios from 'axios';

async function main() {
    // Manually use the fresh stream URL extracted by debug_pattern.ts
    const originalUrl = 'https://edge.cdn-live.ru/secure/api/v1/us-nbc/playlist.m3u8?token=8dd7bd30b42a46c435e087739d5eb5dae6a4fde840a7aeb78af94e81c7c7e56f.1770485121.ebe167af2167f893010156742cefcc21.548062a17847875d70f8e71b40e8fc79.b75ed2e2cbfbc487bd25cfcdc2036e34&signature=327c16b2bebf8c6790c1b60b4050da3afa90a7047400262fc9d5380acfda0c12';

    // Test Direct Connection with Mobile UA
    const targetUrl = originalUrl;

    console.log('Original URL:', originalUrl);
    console.log('Proxy URL:', targetUrl);

    // Cookie from previous curl
    const cookie = 'PHPSESSID=l7lhdm4hu2p03ui9qqeu470did';

    // Exact headers from server.ts
    const headers: any = {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
        'Origin': 'https://cdn-live.tv',
        'Referer': 'https://cdn-live.tv/',
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site'
    };

    if (cookie) headers['Cookie'] = cookie;

    console.log('Headers:', JSON.stringify(headers, null, 2));

    try {
        console.log('Fetching with Axios...');
        const response = await axios.get(targetUrl, {
            headers,
            validateStatus: () => true // Don't throw on 4xx/5xx
        });

        console.log(`Status: ${response.status} ${response.statusText}`);
        console.log('Response Headers:', response.headers);
        if (response.status !== 200) {
            const body = typeof response.data === 'object' ? JSON.stringify(response.data) : response.data.toString();
            console.log('Body:', body.substring(0, 500));
        } else {
            console.log('Body: (Preview)', response.data.toString().substring(0, 100));
        }

    } catch (error: any) {
        console.error('Axios Error:', error.message);
    }
}

main();
