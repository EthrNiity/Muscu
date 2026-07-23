const CACHE_NAME = 'ethrniity-v4';
const APP_FILES = ['./index.html', './manifest.json', './icon-192.png', './icon-512.png'];
const CDN_FILES = ['https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js'];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll([...APP_FILES, ...CDN_FILES]))
      .catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);

  if (url.origin === self.location.origin) {
    // Our own app files: network-first, so updates published on GitHub are
    // picked up immediately when online. Falls back to cache when offline.
    e.respondWith(
      fetch(e.request)
        .then((res) => {
          if (res && res.status === 200) {
            const clone = res.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(e.request, clone));
          }
          return res;
        })
        .catch(() => caches.match(e.request))
    );
  } else if (CDN_FILES.includes(e.request.url)) {
    // Known static external dependencies (CDN): cache-first, fast and stable offline.
    e.respondWith(
      caches.match(e.request).then((cached) => {
        return cached || fetch(e.request).then((res) => {
          if (res && res.status === 200) {
            const clone = res.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(e.request, clone));
          }
          return res;
        });
      })
    );
  } else {
    // Everything else (Supabase API calls, etc.): always go straight to the
    // network, never cache. This data changes constantly and must stay fresh.
    e.respondWith(fetch(e.request));
  }
});
