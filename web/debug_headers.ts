import axios from 'axios';

const testUrl = 'https://cdn-live.tv/api/v1/channels/player/?name=nbc&code=us&user=cdnlivetv&plan=free';

(async () => {
    try {
        console.log('Fetching:', testUrl);
        const res = await axios.get(testUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Referer': 'https://streamsports99.su/'
            }
        });

        console.log('Status:', res.status);
        console.log('Response Headers:', JSON.stringify(res.headers, null, 2));

        if (res.headers['set-cookie']) {
            console.log('\n⚠️ COOKIES FOUND:');
            console.log(res.headers['set-cookie']);
        } else {
            console.log('\n✅ No Set-Cookie header found.');
        }

    } catch (e: any) {
        console.error('Error:', e.message);
    }
})();
