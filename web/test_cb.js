const axios = require('axios');
const url = "https://edge.cdn-live.ru/secure/api/v1/us-abc/playlist.m3u8?token=f763725e7b906c237dca65f048d3955ea5651bb35a108cbcfdc5c6a18714bd40.1771590458.5a39b858ddc550aa3c51b93655dcbdb0.c030ef7575651f0d82ff1387007ce3b3.91f4763d639e53594ecbf2e4493ba85c&signature=06f8705735e719e2b35c8b6790a118511bc589efe37c8fa94e6c80c423f6d124&_cb=" + Date.now();
const headers = {
    "Cookie": "PHPSESSID=06kfh9ntmvbb05gbqi204i0lb4",
    "Origin": "https://cdn-live.tv",
    "Referer": "https://cdn-live.tv/",
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1"
};
axios.get(url, { headers }).then(res => console.log("Success:", res.status)).catch(err => console.error("Error:", err.response ? err.response.status : err.message));
