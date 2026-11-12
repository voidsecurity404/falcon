// Falcon: takes new wallpaper colors without restarting Spotify.
// falcon-app-colors rewrites colors.css next to Spotify's own files
// (spicetify refresh), and this reads it again every 2 seconds and lays it
// over the copy loaded at start.
(function falconLiveColors() {
  let last = "";
  async function check() {
    try {
      const res = await fetch("colors.css?falcon=" + Date.now(), { cache: "no-store" });
      if (!res.ok) return;
      const text = await res.text();
      if (text === last) return;
      if (last) {
        let style = document.getElementById("falcon-live-colors");
        if (!style) {
          style = document.createElement("style");
          style.id = "falcon-live-colors";
          document.head.appendChild(style);
        }
        style.textContent = text;
      }
      last = text;
    } catch (e) {}
  }
  check();
  setInterval(check, 2000);
})();
