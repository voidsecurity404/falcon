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

function looksLikeMath(q) {
    return /^[\d\s+\-*/%^().,]+$/.test(q) && /\d\s*[+\-*/%^]\s*[\d(]/.test(q);
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
