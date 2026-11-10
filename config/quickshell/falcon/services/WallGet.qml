pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Search and downloads of the wallpaper download window (modules/WallpaperBrowser.qml), through
// bin/falcon-wallget. It lives here so results stay between openings and a download carries on
// after the window closes. Downloads run one at a time, in the order asked.
Singleton {
    id: root

    // wallhaven (pictures) or motionbgs (live wallpapers)
    property string source: "wallhaven"
    property string query: ""
    property int page: 1
    property var results: []
    property bool more: false
    property string error: ""
    readonly property bool searching: searchProc.running
    // key "source:id" -> { progress, state: waiting|loading|done|failed, path, apply }
    property var jobs: ({})
    property var queue: []
    property string screenSize: ""

    function keyOf(row) {
        return row.source + ":" + row.id;
    }

    function search(newSource, newQuery) {
        source = newSource;
        query = newQuery;
        page = 1;
        results = [];
        more = false;
        error = "";
        run();
    }

    function loadMore() {
        if (!more || searchProc.running)
            return;
        page += 1;
        run();
    }

    function run() {
        searchProc.running = false;
        searchProc.forPage = page;
        searchProc.forSource = source;
        searchProc.command = [Ui.binDir + "falcon-wallget", "search", source, query, String(page), source === "wallhaven" ? screenSize : ""];
        searchProc.running = true;
    }

    function take(line) {
        let row = null;
        try {
            row = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (searchProc.forSource !== source)
            return;
        if (row.error) {
            if (results.length === 0)
                error = row.error;
            more = false;
            return;
        }
        if (row.done) {
            more = !!row.more;
            return;
        }
        // Keeps the site's order although the pictures arrive as they are fetched.
        row.page = searchProc.forPage;
        const list = results.slice();
        let at = list.length;
        while (at > 0 && (list[at - 1].page > row.page || (list[at - 1].page === row.page && list[at - 1].order > row.order)))
            at -= 1;
        list.splice(at, 0, row);
        results = list;
    }

    function setJob(key, values) {
        const next = Object.assign({}, jobs);
        next[key] = Object.assign({}, next[key] || {}, values);
        jobs = next;
    }

    // Downloads the wallpaper, and with `apply` sets it once it is there.
    function get(row, apply) {
        const key = keyOf(row);
        const job = jobs[key];
        if (job && job.state === "done") {
            if (apply)
                use(job.path);
            return;
        }
        if (job && (job.state === "loading" || job.state === "waiting")) {
            setJob(key, { apply: job.apply || apply });
            return;
        }
        setJob(key, { state: "waiting", progress: 0, apply: apply, row: row });
        queue = queue.concat([key]);
        next();
    }

    function next() {
        if (getProc.running || queue.length === 0)
            return;
        const key = queue[0];
        queue = queue.slice(1);
        const job = jobs[key];
        if (!job)
            return next();
        setJob(key, { state: "loading" });
        getProc.forKey = key;
        getProc.answered = false;
        getProc.command = [Ui.binDir + "falcon-wallget", "get", job.row.source, job.row.id, job.row.url, job.row.title];
        getProc.running = true;
    }

    function use(path) {
        Ui.run("falcon-wallpaper", path);
    }

    function got(line) {
        let answer = null;
        try {
            answer = JSON.parse(line);
        } catch (e) {
            return;
        }
        const key = getProc.forKey;
        const job = jobs[key] || {};
        if (answer.progress !== undefined) {
            setJob(key, { progress: answer.progress });
        } else if (answer.path) {
            getProc.answered = true;
            setJob(key, { state: "done", progress: 1, path: answer.path });
            if (job.apply) {
                use(answer.path);
                // The window steps aside, so the new wallpaper shows.
                if (Ui.popup === "wallget")
                    Ui.popup = "";
            }
            else
                Toasts.show(Tr.t("Saved to wallpapers"), job.row ? job.row.title : "", "wallpaper", () => root.use(answer.path));
            Wallpapers.refresh();
        } else if (answer.error) {
            getProc.answered = true;
            setJob(key, { state: "failed" });
            Toasts.show(Tr.t("Could not download the wallpaper"), answer.error === "type" ? Tr.t("The site sent something else") : Tr.t("Check the internet connection"), "wallpaper");
        }
    }

    Process {
        id: searchProc

        property int forPage: 1
        property string forSource: ""

        stdout: SplitParser {
            onRead: line => root.take(line)
        }
    }

    Process {
        id: getProc

        property string forKey: ""
        property bool answered: false

        stdout: SplitParser {
            onRead: line => root.got(line)
        }
        onExited: {
            if (!answered && root.jobs[forKey] && root.jobs[forKey].state === "loading")
                root.setJob(forKey, { state: "failed" });
            root.next();
        }
    }
}
