// PageClock offline cache. Use network-first so web deployments are not
// hidden behind a stale cache-first main.dart.js or index.html.
const CACHE_NAME = 'pageclock-brand-v5';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './main.dart.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './completion_audio.js',
  ...['calm', 'rain', 'forest', 'ocean', 'bell', 'classic'].map(name => './assets/assets/audio/' + name + '.wav'),
  './manifest.json',
  './favicon.png',
  './icons/apple-touch-icon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(ASSETS_TO_CACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((key) => key.startsWith('pageclock-brand-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const requestUrl = new URL(request.url);
  if (requestUrl.origin !== self.location.origin) return;

  // Bypass caching and cache writes for requests carrying auth callback/error params.
  const hasAuthParams = requestUrl.searchParams.has('code') || requestUrl.searchParams.has('error');

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);

    // Always prefer the current deployment when online. Refresh the offline
    // copy in the background of this response path so future offline opens
    // still have the latest successfully downloaded shell and assets.
    try {
      const response = await fetch(request);
      if (response && response.status === 200 && response.type === 'basic' && !hasAuthParams) {
        await cache.put(request, response.clone());
      }
      return response;
    } catch (_) {
      if (!hasAuthParams) {
        const cached = await cache.match(request);
        if (cached) return cached;
      }

      if (request.mode === 'navigate') {
        const shell = await cache.match('./index.html');
        if (shell) return shell;
      }

      return Response.error();
    }
  })());
});
