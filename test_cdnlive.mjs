// test_cdnlive.mjs
// Test d'extraction du flux cdn-live.tv
// Usage: node test_cdnlive.mjs

import puppeteer from 'puppeteer';

const PLAYER_URL = 'https://cdn-live.tv/api/v1/channels/player/?name=abc&code=us&user=cdnlivetv&plan=free';
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

async function extractStream() {
    console.log('🚀 Démarrage extraction cdn-live.tv...');
    console.log(`URL: ${PLAYER_URL}\n`);

    const browser = await puppeteer.launch({
        headless: 'new',
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-web-security',
            '--disable-features=IsolateOrigins,site-per-process',
        ]
    });

    const page = await browser.newPage();
    await page.setUserAgent(UA);

    let m3u8Url = null;
    let foundCookies = null;

    // Intercepter les requêtes réseau
    await page.setRequestInterception(true);
    page.on('request', req => {
        const url = req.url();
        if (url.includes('.m3u8')) {
            console.log(`🎯 [Request] M3U8 détecté: ${url.substring(0, 120)}`);
            if (!m3u8Url) m3u8Url = url;
        }
        req.continue();
    });

    page.on('response', async response => {
        const url = response.url();
        const status = response.status();
        if (url.includes('.m3u8')) {
            console.log(`📥 [Response] M3U8 réponse: ${status} - ${url.substring(0, 120)}`);
            if (!m3u8Url) m3u8Url = url;
        }
        if (url.includes('cdn-live') && status !== 200) {
            console.log(`⚠️ [Response] ${status} - ${url.substring(0, 100)}`);
        }
    });

    console.log('📄 Chargement de la page player...');
    try {
        await page.goto(PLAYER_URL, {
            waitUntil: 'networkidle2',
            timeout: 20000
        });
    } catch (e) {
        console.log(`⚠️ Navigation timeout (normal pour les players): ${e.message}`);
    }

    // Attendre quelques secondes pour que le player s'initialise
    console.log('\n⏳ Attente player (5s)...');
    await new Promise(r => setTimeout(r, 5000));

    // Récupérer les cookies
    foundCookies = await page.cookies();
    console.log(`\n🍪 Cookies (${foundCookies.length}):`);
    for (const c of foundCookies) {
        console.log(`   ${c.name}=${c.value.substring(0, 30)}... (domain: ${c.domain})`);
    }

    // Essayer de récupérer l'URL M3U8 via JavaScript si pas encore trouvée
    if (!m3u8Url) {
        console.log('\n🔍 Recherche M3U8 via JS dans les éléments video...');
        m3u8Url = await page.evaluate(() => {
            const videos = document.querySelectorAll('video');
            for (const v of videos) {
                if (v.src && v.src.includes('.m3u8')) return v.src;
                // Check source elements
                for (const s of v.querySelectorAll('source')) {
                    if (s.src && s.src.includes('.m3u8')) return s.src;
                }
            }
            // Check HLS.js or JWPlayer config
            if (window.hls && window.hls.url) return window.hls.url;
            return null;
        });
    }

    // Analyser le HTML pour trouver des indices
    if (!m3u8Url) {
        console.log('\n🔍 Analyse HTML pour trouver des URL...');
        const content = await page.content();
        const m3u8Match = content.match(/https?:\/\/[^"'\s]+\.m3u8[^"'\s]*/);
        if (m3u8Match) {
            m3u8Url = m3u8Match[0];
            console.log(`   Trouvé dans HTML: ${m3u8Url}`);
        }

        // Chercher des patterns communs
        const patterns = [
            /file:\s*["']([^"']+\.m3u8[^"']*)/,
            /src:\s*["']([^"']+\.m3u8[^"']*)/,
            /"url":\s*"([^"]+\.m3u8[^"]*)"/,
            /"source":\s*"([^"]+\.m3u8[^"]*)"/,
        ];
        for (const p of patterns) {
            const match = content.match(p);
            if (match && !m3u8Url) {
                m3u8Url = match[1];
                console.log(`   Pattern trouvé: ${m3u8Url.substring(0, 100)}`);
            }
        }
    }

    if (m3u8Url) {
        console.log(`\n✅ M3U8 URL trouvée: ${m3u8Url}`);

        // Construire le string cookie
        const cookieStr = foundCookies.map(c => `${c.name}=${c.value}`).join('; ');
        console.log(`\nCookie string: ${cookieStr.substring(0, 100)}`);

        // Tester l'accès au M3U8 avec le cookie
        console.log('\n🧪 Test accès M3U8...');
        try {
            const resp = await fetch(m3u8Url, {
                headers: {
                    'User-Agent': UA,
                    'Referer': 'https://cdn-live.tv/',
                    'Origin': 'https://cdn-live.tv',
                    'Cookie': cookieStr,
                }
            });
            console.log(`   Status: ${resp.status}`);
            if (resp.ok) {
                const text = await resp.text();
                console.log(`   Contenu (${text.length} bytes):`);
                console.log(text.substring(0, 500));

                // Extraire les segments du manifest
                const segments = text.split('\n').filter(l => l.startsWith('http')).slice(0, 3);
                if (segments.length > 0) {
                    console.log(`\n🎬 Test segment (${segments[0].substring(0, 80)})...`);
                    const segResp = await fetch(segments[0], {
                        headers: {
                            'User-Agent': UA,
                            'Referer': 'https://cdn-live.tv/',
                            'Origin': 'https://cdn-live.tv',
                            'Cookie': cookieStr,
                        }
                    });
                    console.log(`   Segment status: ${segResp.status} (${segResp.headers.get('content-type')})`);
                }
            } else {
                const body = await resp.text();
                console.log(`   Erreur body: ${body.substring(0, 200)}`);
            }
        } catch (e) {
            console.log(`   Fetch error: ${e.message}`);
        }
    } else {
        console.log('\n❌ Aucune URL M3U8 trouvée');

        // Dump des infos pour investigation
        const title = await page.title();
        const url = page.url();
        console.log(`Page title: ${title}`);
        console.log(`Final URL: ${url}`);

        const content = await page.content();
        console.log(`\n--- HTML Preview (500 chars) ---`);
        console.log(content.substring(0, 500));
    }

    await browser.close();
    console.log('\n✅ Test terminé');
}

extractStream().catch(e => {
    console.error('❌ Erreur fatale:', e);
    process.exit(1);
});
