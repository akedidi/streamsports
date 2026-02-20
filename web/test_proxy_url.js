const axios = require('axios');
const url = "https://streamsports-wine.vercel.app/api/proxy?url=https://edge.cdn-live.ru/secure/api/v1/us-abc/playlist.m3u8?token%3D05b9c606e1024209580f769994c53bcda55c720efb7afa3ec7dc6177c28e4e02.1771588047.536766203903011ab539b3ad1d72f4e5.511dcfadea9f40deb4bb52ae7f041ec2.066b3150d3e33b456e99f0babf255699%26signature%3Daa11ff76b86262f064531a4f1ea900a24f797af229c8c83985595abb53620745&referer=https://cdn-live.tv/&force_proxy=true&cookie=PHPSESSID%3Db7j99702n4kdg87q7j2v7od4bn";
axios.get(url, { headers: { 'User-Agent': 'AppleCoreMedia/1.0.0.19G82 (iPhone; U; CPU OS 15_6_1 like Mac OS X; en_us)' } })
  .then(res => {
    console.log(res.data);
  })
  .catch(err => {
    console.error("Error:", err.message);
  });
