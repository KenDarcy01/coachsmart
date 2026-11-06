/* My gym QR service worker: lets the home-screen app open with no signal.
 * Network-first for the page's own files, cached copy as the fallback; the crest is cached on use. */
const CACHE = 'gym-qr-v1';
const SHELL = ['./', './index.html', './gym-qr.js?v=1', './vendor/qrcode.js?v=1', './manifest.webmanifest', './icon.svg', './icon-180.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k.startsWith('gym-qr-') && k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const own = url.origin === location.origin && url.pathname.includes('/gym-qr/');
  if (!own && req.destination !== 'image') return;
  if (!own) {
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
  }).catch(() => caches.match(req).then(hit => hit || caches.match('./index.html'))));
});
