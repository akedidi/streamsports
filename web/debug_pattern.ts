import fs from 'fs';

const html = fs.readFileSync('/tmp/player_response_new.html', 'utf8');

// Decode
const startMarker = '}("';
const startIdx = html.indexOf(startMarker);
const actualStart = startIdx + startMarker.length;
const endIdx = html.indexOf('",', actualStart);
const encoded = html.substring(actualStart, endIdx);
const paramsPos = endIdx + 2;
const params = html.substring(paramsPos, paramsPos + 100);
const match = params.match(/(\d+),\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*(\d+)/);

function convertBase(s: string, base: number): number {
    let result = 0;
    for (const c of s) {
        result = result * base + parseInt(c, 10);
    }
    return result;
}

const charset = match![2];
const offset = parseInt(match![3], 10);
const base = parseInt(match![4], 10);

let decoded = '';
const parts = encoded.split(charset[base]);
for (const part of parts) {
    if (part) {
        let temp = part;
        for (let idx = 0; idx < charset.length; idx++) {
            temp = temp.split(charset[idx]).join(String(idx));
        }
        const val = convertBase(temp, base);
        decoded += String.fromCharCode(val - offset);
    }
}
try { decoded = decodeURIComponent(decoded); } catch { }

// Extract all const assignments with Base64 values
const varPattern = /const\s+(\w+)\s*=\s*'([A-Za-z0-9+/=_-]+)'/g;
const vars: Record<string, string> = {};
let varMatch;
while ((varMatch = varPattern.exec(decoded)) !== null) {
    const [, name, b64Value] = varMatch;
    try {
        let b64 = b64Value.replace(/-/g, '+').replace(/_/g, '/');
        while (b64.length % 4) b64 += '=';
        vars[name] = Buffer.from(b64, 'base64').toString('utf8');
    } catch {
        vars[name] = b64Value;
    }
}

// Detect decoder function name
const funcMatch = decoded.match(/function\s+(\w+)\(str\)/);
const decoderName = funcMatch ? funcMatch[1] : 'jNJVVkAypbee';

// Concat pattern
const safeName = decoderName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const concatPattern = new RegExp(`const\\s+\\w+\\s*=\\s*([^;]+${safeName}[^;]+);`, 'g');

let concatMatch;
while ((concatMatch = concatPattern.exec(decoded)) !== null) {
    const expression = concatMatch[1];
    const callRegex = new RegExp(`${safeName}\\((\\w+)\\)`, 'g');
    const varNames = expression.match(callRegex);

    if (varNames && varNames.length > 0) {
        let url = '';
        for (const call of varNames) {
            const nameRegex = new RegExp(`${safeName}\\((\\w+)\\)`);
            const nameMatch = call.match(nameRegex);
            if (nameMatch && vars[nameMatch[1]]) {
                url += vars[nameMatch[1]];
            }
        }

        if (url.includes('.m3u8') && url.startsWith('http')) {
            console.log('VALID STREAM URL FOUND');
            console.log(url);
        }
    }
}
