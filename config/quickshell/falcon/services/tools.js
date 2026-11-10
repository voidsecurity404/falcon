.pragma library

// Qidiruv oynasidagi hisoblash vositalari.

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

// Ruscha klaviaturada yozilgan bo'lsa, lotin ko'rinishi ham tekshiriladi.
function score(name, q, extra) {
    return Math.max(scoreOne(name, q, extra), scoreOne(name, swapLayout(q), extra));
}

// Boshidan yoki so'z boshidan mos kelsa yuqoriroq. Harflar orasidagi izlash faqat nomda ishlaydi.
function scoreOne(name, q, extra) {
    if (q === "")
        return 1;
    const hay = name.toLowerCase();
    const direct = hay.indexOf(q);
    if (direct === 0)
        return 1000;
    if (direct > 0)
        return (hay[direct - 1] === " " ? 800 : 500) - direct;
    if (extra && extra.toLowerCase().indexOf(q) >= 0)
        return 300;
    let at = -1;
    for (const ch of q) {
        at = hay.indexOf(ch, at + 1);
        if (at < 0)
            return 0;
    }
    return 100 - at;
}

// Which card of a fan a pointer means. Slots are fixed, so the moving cards cannot change the
// answer under a still pointer, and the current card keeps a margin past the middle between two.
function fanSlot(x, center, spacing, count, current) {
    const offset = (x - center) / spacing + (count - 1) / 2;
    if (current >= 0 && current < count && Math.abs(offset - current) < 0.64)
        return current;
    return Math.max(0, Math.min(count - 1, Math.round(offset)));
}

// Web search in the app menu. A bang picks the site: "!yt lofi" or "lofi !yt", like DuckDuckGo.
// `{q}` in a template is the encoded query. Ids are what is typed after "!".
const BANGS = [
    { id: "g", name: "Google", url: "https://www.google.com/search?q={q}", home: "https://www.google.com" },
    { id: "yt", name: "YouTube", url: "https://www.youtube.com/results?search_query={q}", home: "https://www.youtube.com" },
    { id: "w", name: "Wikipedia", url: "https://{lang}.wikipedia.org/w/index.php?search={q}", home: "https://{lang}.wikipedia.org" },
    { id: "img", name: "Google Images", url: "https://www.google.com/search?tbm=isch&q={q}", home: "https://images.google.com" },
    { id: "maps", name: "Google Maps", url: "https://www.google.com/maps/search/{q}", home: "https://www.google.com/maps" },
    { id: "tr", name: "Google Translate", url: "https://translate.google.com/?sl=auto&tl={lang}&text={q}", home: "https://translate.google.com" },
    { id: "gh", name: "GitHub", url: "https://github.com/search?q={q}", home: "https://github.com" },
    { id: "aw", name: "ArchWiki", url: "https://wiki.archlinux.org/index.php?search={q}", home: "https://wiki.archlinux.org" },
    { id: "aur", name: "AUR", url: "https://aur.archlinux.org/packages?K={q}", home: "https://aur.archlinux.org" },
    { id: "pkg", name: "Arch packages", url: "https://archlinux.org/packages/?q={q}", home: "https://archlinux.org/packages" },
    { id: "r", name: "Reddit", url: "https://www.reddit.com/search/?q={q}", home: "https://www.reddit.com" },
    { id: "so", name: "Stack Overflow", url: "https://stackoverflow.com/search?q={q}", home: "https://stackoverflow.com" },
    { id: "ya", name: "Yandex", url: "https://yandex.ru/search/?text={q}", home: "https://yandex.ru" },
    { id: "ddg", name: "DuckDuckGo", url: "https://duckduckgo.com/?q={q}", home: "https://duckduckgo.com" },
    { id: "ym", name: "YouTube Music", url: "https://music.youtube.com/search?q={q}", home: "https://music.youtube.com" },
    { id: "wh", name: "Wallhaven", url: "https://wallhaven.cc/search?q={q}", home: "https://wallhaven.cc" }
];

function bangUrl(bang, query, lang) {
    const template = query === "" ? bang.home : bang.url;
    return template.split("{lang}").join(lang || "en").split("{q}").join(encodeURIComponent(query));
}

// Splits "!yt lofi", "lofi !yt" or "!yt" into { bang, query, partial }. `partial` is the bang being
// typed when it is the whole text so far ("!y"), so the menu can offer the bangs that start with it.
function webParts(text) {
    const words = text.trim().split(/\s+/).filter(w => w !== "");
    let bang = null;
    let partial = null;
    const rest = [];
    for (let i = 0; i < words.length; i++) {
        const word = words[i];
        if (word.length > 1 && word[0] === "!") {
            const id = word.slice(1).toLowerCase();
            const found = BANGS.find(b => b.id === id) || BANGS.find(b => b.id === swapLayout(id));
            if (found && !bang) {
                bang = found;
                continue;
            }
            if (words.length === 1)
                partial = id;
        } else if (word === "!" && words.length === 1) {
            partial = "";
            continue;
        }
        rest.push(word);
    }
    return { bang: bang, query: rest.join(" "), partial: partial };
}

// A typed address: "github.com/x", "https://...", "localhost:8080". Not plain words or sums.
function asAddress(text) {
    const t = text.trim();
    if (t === "" || /\s/.test(t))
        return "";
    if (/^https?:\/\/\S+$/i.test(t))
        return t;
    if (/^localhost(:\d+)?(\/\S*)?$/i.test(t) || /^(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/\S*)?$/.test(t))
        return "http://" + t;
    if (/^([a-z0-9-]+\.)+[a-z]{2,}(:\d+)?(\/\S*)?$/i.test(t) && !/^\d+(\.\d+)+$/.test(t))
        return "https://" + t;
    return "";
}
