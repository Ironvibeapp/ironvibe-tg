// Intentionally empty: Telegram Android WebView + a caching SW caused
// a stuck first paint. The Mini App is hosted on GitHub Pages HTTPS.
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (key) { return caches.delete(key); }));
    }).then(function () {
      return self.registration.unregister();
    }),
  );
});
