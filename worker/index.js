// blink20.net edge worker — serves the static site and counts two things:
//
//   /appcast.xml   Sparkle's daily update check (already happening; the app
//                  is unchanged). Sparkle's User-Agent carries the installed
//                  app version, e.g. "Blink/5.2.3 Sparkle/2.9.0".
//   /download      302 → latest DMG on GitHub Releases. The website links
//                  here so website downloads can be told apart from Sparkle
//                  updates (which fetch the GitHub asset directly).
//
// Privacy: nothing identifying is stored — no IP, no cookie, no fingerprint,
// no per-request rows. D1 holds one daily counter per
// (event, app version, sparkle version, OS family). Query with `make stats`.

const DMG_URL = "https://github.com/D4G4/blink/releases/latest/download/Blink.dmg";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    try {
      if (url.pathname === "/appcast.xml") {
        ctx.waitUntil(count(env, "appcast", request));
      } else if (url.pathname === "/download" || url.pathname === "/download/") {
        ctx.waitUntil(count(env, "download", request));
        return Response.redirect(DMG_URL, 302);
      }
    } catch (_) {
      // Counting must never break serving.
    }
    return env.ASSETS.fetch(request);
  },
};

async function count(env, event, request) {
  if (!env.BLINK_DB) return;
  const ua = request.headers.get("user-agent") || "";
  const appVersion = (ua.match(/Blink\/([\w.\-]+)/) || [])[1] || "";
  const sparkleVersion = (ua.match(/Sparkle\/([\w.\-]+)/) || [])[1] || "";
  const os = /Macintosh|Mac OS|Darwin|Sparkle/.test(ua) ? "mac"
    : /Windows/.test(ua) ? "windows"
    : /iPhone|iPad|Android/.test(ua) ? "mobile"
    : "other";
  const day = new Date().toISOString().slice(0, 10);
  try {
    await env.BLINK_DB.prepare(
      `INSERT INTO events (day, event, app_version, sparkle_version, os, count)
       VALUES (?1, ?2, ?3, ?4, ?5, 1)
       ON CONFLICT (day, event, app_version, sparkle_version, os)
       DO UPDATE SET count = count + 1`
    ).bind(day, event, appVersion, sparkleVersion, os).run();
  } catch (_) {
    // Never surface counting failures to the user.
  }
}
