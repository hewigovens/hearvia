// Serves hearvia.hewig.dev from the GitHub Pages site, so a push to docs/ publishes here too.
const origin = "https://hewigovens.github.io/hearvia";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const upstream = await fetch(origin + url.pathname + url.search, {
      method: request.method,
      headers: { "Accept-Encoding": request.headers.get("Accept-Encoding") ?? "" },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    const response = new Response(upstream.body, upstream);
    // GitHub's own redirects (a folder without its slash) point back at github.io.
    const location = response.headers.get("Location");
    if (location?.startsWith(origin)) {
      response.headers.set("Location", url.origin + location.slice(origin.length));
    }
    return response;
  },
};
