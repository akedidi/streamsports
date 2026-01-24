import axios from 'axios';

const targetUrl = "https://cdn-live.tv/api/v1/channels/player/?name=arena+sport+2&code=hr&user=streamsports99&plan=vip";
const proxyUrl = "https://corsproxy.io/?";

async function debugProxy() {
    const fullUrl = proxyUrl + encodeURIComponent(targetUrl);
    console.log("Testing Proxy URL: " + fullUrl);

    try {
        const res = await axios.get(fullUrl, {
            headers: {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            }
        });

        console.log("Status:", res.status);
        if (res.status === 200) {
            console.log("Data snippet:", res.data.substring(0, 100));

            // Regex to find m3u8
            const pattern = /[\"']([^\"']*index\.m3u8\?token=[^\"']+)[\"']/;
            const match = res.data.match(pattern);

            if (match) {
                console.log("SUCCESS! Found token:", match[1]);
            } else {
                console.log("FAILED: No token found in HTML");
            }
        }
    } catch (e: any) {
        console.error("Proxy Request Failed:", e.message);
        if (e.response) {
            console.log("Status:", e.response.status);
            console.log("Data:", e.response.data);
        }
    }
}

debugProxy();
