addEventListener('fetch', event => {
  event.respondWith(handle(event.request));
});

async function handle(request) {
  const url = new URL(request.url);
  const run = url.searchParams.get('RUN');
  if (!run) {
    return new Response(JSON.stringify({ error: 'Missing RUN' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  const target = 'https://script.google.com/macros/s/AKfycbyIjxmxJGzjIUYFxoMg48sgFcXY_6yNKQe_IZ4X5zqseYEpb_24uVqGEZ-VO9r5cKKh/exec?RUN=' + encodeURIComponent(run);

  // fetch the script; follow redirects automatically in Cloudflare Workers
  const resp = await fetch(target, { redirect: 'follow' });
  const text = await resp.text();
  // try to return JSON; if the response is already JSON, forward with content-type
  return new Response(text, {
    status: resp.status,
    headers: { 'Content-Type': resp.headers.get('Content-Type') ?? 'application/json' }
  });
}
