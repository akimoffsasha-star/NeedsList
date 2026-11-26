/* Static application shell cache. Supabase/API requests are deliberately never cached. */
const CACHE_NAME = 'needslist-shell-v2.0.0';
const APP_FILES = [
  './', './index.html', './admin.html', './enterprise.html', './reports.html',
  './dashboard.html', './qa.html', './proposal.html', './portfolio.html',
  './monitoring.html', './assistance.html', './style.css', './common.js',
  './config.js', './pwa.js', './manifest.webmanifest', './offline.html', './icon-192.png', './icon-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(key => key.startsWith('needslist-shell-') && key !== CACHE_NAME).map(key => caches.delete(key))
  )).then(() => self.clients.claim()));
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).then(response => {
      const copy = response.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
      return response;
    }).catch(async () => (await caches.match(request)) || (await caches.match('./offline.html'))));
    return;
  }

  event.respondWith(caches.match(request).then(cached => {
    const network = fetch(request).then(response => {
      if (response && response.ok) {
        const copy = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
      }
      return response;
    }).catch(() => cached);
    return cached || network;
  }));
});
