const axios = require('axios');
// Extract the embedded direct CDN URL from the proxy URL
const directUrlObj = new URL("https://streamsports-wine.vercel.app/api/proxy?url=https%3A%2F%2Fedge.cdn-google.ru%2Fsecure%2Fapi%2Fv1%2Fus-abc%2FMjAyNi8wMi8yMC8xMS81Mi80Ny0wNTAwNQ.ts%3Ftoken%3D05b9c606e1024209580f769994c53bcda55c720efb7afa3ec7dc6177c28e4e02.1771588047.536766203903011ab539b3ad1d72f4e5.511dcfadea9f40deb4bb52ae7f041ec2.066b3150d3e33b456e99f0babf255699%26signature%3Daa11ff76b86262f064531a4f1ea900a24f797af229c8c83985595abb53620745&referer=https%3A%2F%2Fcdn-live.tv%2F&force_proxy=true&cookie=PHPSESSID%3Db7j99702n4kdg87q7j2v7od4bn");
const directUrl = directUrlObj.searchParams.get('url');

axios.get(directUrl, {
    responseType: 'arraybuffer',
    headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://cdn-live.tv/',
        'Cookie': 'PHPSESSID=b7j99702n4kdg87q7j2v7od4bn'
    }
})
    .then(res => {
        console.log("Direct Status:", res.status);
        console.log("Segment length:", res.data.length);
    })
    .catch(err => {
        console.error("Direct Error:", err.message);
        if (err.response) {
            console.error("Status:", err.response.status);
            console.error("Data:", err.response.data.toString());
        }
    });
