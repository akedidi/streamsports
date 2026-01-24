import axios from 'axios';

const url = "https://cdn-live.tv/api/v1/channels/player/?name=arena+sport+2&code=hr&user=streamsports99&plan=vip";

async function debugStream() {
    try {
        console.log("Fetching: " + url);
        const res = await axios.get(url, {
            headers: {
                "Referer": "https://cdn-live.tv/",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
            }
        });

        console.log("Status:", res.status);
        console.log("Headers:", res.headers);
        console.log("Body Length:", res.data.length);
        console.log("Snippet:", res.data.substring(0, 200));

        const pattern = /[\"']([^\"']*index\.m3u8\?token=[^\"']+)[\"']/;
        const match = res.data.match(pattern);

        if (match) {
            console.log("FOUND TOKEN:", match[1]);
        } else {
            console.log("NO TOKEN FOUND");
        }

    } catch (e: any) {
        console.error("Error:", e.message);
        if (e.response) {
            console.log("Status:", e.response.status);
            console.log("Data:", e.response.data);
        }
    }
}

debugStream();
