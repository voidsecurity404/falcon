.pragma library

// Qidiruv oynasidagi hisoblash va kodlash vositalari.

// Oddiy arifmetik tahlilchi: + - * / % ^ va qavslar. eval ishlatilmaydi.
function calc(input) {
    const s = input.replace(/\s+/g, "").replace(/,/g, ".");
    let i = 0;
    function number() {
        const m = /^\d*\.?\d+/.exec(s.slice(i));
        if (!m)
            throw new Error("number expected");
        i += m[0].length;
        return parseFloat(m[0]);
    }
    function atom() {
        if (s[i] === "-") {
            i++;
            return -atom();
        }
        if (s[i] === "(") {
            i++;
            const v = sum();
            if (s[i] !== ")")
                throw new Error("unclosed parenthesis");
            i++;
            return v;
        }
        return number();
    }
    function power() {
        const base = atom();
        if (s[i] === "^") {
            i++;
            return Math.pow(base, power());
        }
        return base;
    }
    function product() {
        let v = power();
        while (s[i] === "*" || s[i] === "/" || s[i] === "%") {
            const op = s[i++];
            const r = power();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function sum() {
        let v = product();
        while (s[i] === "+" || s[i] === "-") {
            const op = s[i++];
            const r = product();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }
    const value = sum();
    if (i !== s.length || !isFinite(value))
        throw new Error("invalid expression");
    return String(Math.round(value * 1e10) / 1e10);
}

function looksLikeMath(q) {
    return /^[\d\s+\-*/%^().,]+$/.test(q) && /\d\s*[+\-*/%^]\s*[\d(]/.test(q);
}

function utf8Bytes(text) {
    return unescape(encodeURIComponent(text));
}

function toHex(text) {
    const b = utf8Bytes(text);
    let out = "";
    for (let i = 0; i < b.length; i++)
        out += b.charCodeAt(i).toString(16).padStart(2, "0");
    return out;
}

function fromHex(text) {
    const clean = text.replace(/\s+/g, "");
    if (clean.length % 2 !== 0 || /[^0-9a-fA-F]/.test(clean))
        throw new Error("not hex");
    let b = "";
    for (let i = 0; i < clean.length; i += 2)
        b += String.fromCharCode(parseInt(clean.substr(i, 2), 16));
    return decodeURIComponent(escape(b));
}

const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

function toBase64(text) {
    const b = utf8Bytes(text);
    let out = "";
    for (let i = 0; i < b.length; i += 3) {
        const n = (b.charCodeAt(i) << 16) | ((b.charCodeAt(i + 1) || 0) << 8) | (b.charCodeAt(i + 2) || 0);
        out += B64[n >> 18] + B64[(n >> 12) & 63];
        out += i + 1 < b.length ? B64[(n >> 6) & 63] : "=";
        out += i + 2 < b.length ? B64[n & 63] : "=";
    }
    return out;
}

function fromBase64(text) {
    const clean = text.replace(/\s+/g, "").replace(/-/g, "+").replace(/_/g, "/").replace(/=+$/, "");
    if (/[^A-Za-z0-9+/]/.test(clean) || clean.length % 4 === 1)
        throw new Error("not base64");
    let b = "";
    let bits = 0;
    let buffer = 0;
    for (let i = 0; i < clean.length; i++) {
        buffer = (buffer << 6) | B64.indexOf(clean[i]);
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            b += String.fromCharCode((buffer >> bits) & 255);
        }
    }
    return decodeURIComponent(escape(b));
}

// Pentest uchun tez o'girish: buyruq nomi va natija. Mos kelmasa null.
// md5 QML'dagi Qt obyektidan uzatiladi.
function encode(query, qt) {
    const m = /^(b64|b64d|url|urld|hex|hexd|md5|sha256|html|htmld|jwt|hashid)\s+([\s\S]+)$/.exec(query);
    if (!m)
        return null;
    const text = m[2];
    try {
        const more = encodeMore(m[1], text);
        if (more)
            return more;
        switch (m[1]) {
        case "b64":
            return { label: "Base64", value: toBase64(text) };
        case "b64d":
            return { label: "Base64 decoded", value: fromBase64(text) };
        case "url":
            return { label: "URL encoded", value: encodeURIComponent(text) };
        case "urld":
            return { label: "URL decoded", value: decodeURIComponent(text) };
        case "hex":
            return { label: "Hex", value: toHex(text) };
        case "hexd":
            return { label: "Hex decoded", value: fromHex(text) };
        case "md5":
            return { label: "MD5", value: qt.md5(text) };
        }
    } catch (e) {
        return { label: "Could not decode", value: "" };
    }
    return null;
}

// Qator noto'g'ri tilda yozilsa: ruscha klaviatura harflarini lotin tugmalariga aylantiradi.
const RU = "йцукенгшщзхъфывапролджэячсмитьбю";
const EN = "qwertyuiop[]asdfghjkl;'zxcvbnm,.";

function swapLayout(text) {
    let out = "";
    for (const ch of text) {
        const a = RU.indexOf(ch);
        const b = a < 0 ? EN.indexOf(ch) : -1;
        out += a >= 0 ? EN[a] : b >= 0 ? RU[b] : ch;
    }
    return out;
}

function sha256(text) {
    const k = [];
    const h = [];
    const frac = x => ((x - Math.floor(x)) * 4294967296) >>> 0;
    for (let n = 2, c = 0; c < 64; n++) {
        let prime = true;
        for (let d = 2; d * d <= n; d++)
            if (n % d === 0) {
                prime = false;
                break;
            }
        if (prime) {
            if (c < 8)
                h.push(frac(Math.pow(n, 1 / 2)));
            k.push(frac(Math.pow(n, 1 / 3)));
            c++;
        }
    }
    const b = utf8Bytes(text);
    const bytes = [];
    for (let i = 0; i < b.length; i++)
        bytes.push(b.charCodeAt(i));
    const bits = bytes.length * 8;
    bytes.push(0x80);
    while (bytes.length % 64 !== 56)
        bytes.push(0);
    const hi = Math.floor(bits / 4294967296);
    for (const v of [hi, bits >>> 0])
        bytes.push((v >>> 24) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255);
    const rot = (x, n) => (x >>> n) | (x << (32 - n));
    for (let i = 0; i < bytes.length; i += 64) {
        const w = [];
        for (let t = 0; t < 16; t++)
            w[t] = ((bytes[i + t * 4] << 24) | (bytes[i + t * 4 + 1] << 16) | (bytes[i + t * 4 + 2] << 8) | bytes[i + t * 4 + 3]) >>> 0;
        for (let t = 16; t < 64; t++) {
            const s0 = rot(w[t - 15], 7) ^ rot(w[t - 15], 18) ^ (w[t - 15] >>> 3);
            const s1 = rot(w[t - 2], 17) ^ rot(w[t - 2], 19) ^ (w[t - 2] >>> 10);
            w[t] = (w[t - 16] + s0 + w[t - 7] + s1) >>> 0;
        }
        let [a, bb, c, d, e, f, g, hh] = h;
        for (let t = 0; t < 64; t++) {
            const t1 = (hh + (rot(e, 6) ^ rot(e, 11) ^ rot(e, 25)) + ((e & f) ^ (~e & g)) + k[t] + w[t]) >>> 0;
            const t2 = ((rot(a, 2) ^ rot(a, 13) ^ rot(a, 22)) + ((a & bb) ^ (a & c) ^ (bb & c))) >>> 0;
            hh = g;
            g = f;
            f = e;
            e = (d + t1) >>> 0;
            d = c;
            c = bb;
            bb = a;
            a = (t1 + t2) >>> 0;
        }
        [a, bb, c, d, e, f, g, hh].forEach((v, idx) => h[idx] = (h[idx] + v) >>> 0);
    }
    return h.map(v => v.toString(16).padStart(8, "0")).join("");
}

function htmlEncode(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

function htmlDecode(text) {
    return text.replace(/&#(\d+);/g, (m, n) => String.fromCodePoint(Number(n))).replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&");
}

// JWT'ning sarlavha va ma'lumot qismini ochadi. Imzo tekshirilmaydi.
function jwtDecode(token) {
    const parts = token.trim().split(".");
    if (parts.length !== 3)
        throw new Error("not a jwt");
    return JSON.stringify(JSON.parse(fromBase64(parts[0]))) + " " + JSON.stringify(JSON.parse(fromBase64(parts[1])));
}

// Xesh turini uzunligi va ko'rinishidan taxmin qiladi.
function hashId(text) {
    const s = text.trim();
    if (/^\$2[aby]\$/.test(s))
        return "bcrypt";
    if (/^\$argon2/.test(s))
        return "Argon2";
    if (/^\$6\$/.test(s))
        return "SHA-512 crypt";
    if (/^\$5\$/.test(s))
        return "SHA-256 crypt";
    if (/^\$1\$/.test(s))
        return "MD5 crypt";
    if (/^[0-9a-fA-F]+$/.test(s)) {
        const known = { 32: "MD5 or NTLM", 40: "SHA-1", 56: "SHA-224", 64: "SHA-256", 96: "SHA-384", 128: "SHA-512" };
        return known[s.length] || "Unknown hex hash";
    }
    return "Unknown";
}

function encodeMore(command, text) {
    switch (command) {
    case "sha256":
        return { label: "SHA-256", value: sha256(text) };
    case "html":
        return { label: "HTML encoded", value: htmlEncode(text) };
    case "htmld":
        return { label: "HTML decoded", value: htmlDecode(text) };
    case "jwt":
        return { label: "JWT decoded (signature not verified)", value: jwtDecode(text) };
    case "hashid":
        return { label: "Hash type", value: hashId(text) };
    }
    return null;
}

// Snippet ichidagi {target}, {lhost}, {lport} joylarini to'ldiradi.
function fillSnippet(text, values) {
    return text.replace(/\{(target|lhost|lport)\}/g, (m, key) => values[key] !== undefined && values[key] !== "" ? values[key] : m);
}
