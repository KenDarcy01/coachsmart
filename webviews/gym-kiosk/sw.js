/* Gym kiosk service worker: lets the page open with no Wi-Fi.
 * App files are network-first (so updates land straight away) with the cached copy as
 * the fallback. The crest image is cached on first use. API calls are never cached;
 * the page keeps its own copy of today's data and a queue of check-ins in localStorage. */
const CACHE = 'gym-kiosk-v13';
const SHELL = ['./', './index.html', './kiosk.css?v=10', './kiosk.js?v=11', './manifest.webmanifest', './icon.svg', './icon-180.png', './vendor/jsQR.js?v=1'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k.startsWith('gym-kiosk-') && k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const isShell = url.origin === location.origin && url.pathname.includes('/gym-kiosk/');
  const isImage = req.destination === 'image';
  if (!isShell && !isImage) return;

  if (isImage && !isShell) {
    // Crest: cache first, refresh in the background.
    e.respondWith(caches.open(CACHE).then(async c => {
      const hit = await c.match(req);
      const net = fetch(req).then(r => { if (r.ok || r.type === 'opaque') c.put(req, r.clone()); return r; }).catch(() => hit);
      return hit || net;
    }));
    return;
  }

  e.respondWith(fetch(req).then(r => {
    if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
    return r;
  }).catch(() => caches.match(req, { ignoreSearch: false }).then(hit => hit || caches.match('./index.html'))));
});
