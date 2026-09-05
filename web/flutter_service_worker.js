// Retire only this legacy Flutter worker, preserving Firebase messaging.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Current releases use versioned assets without a Flutter cache worker.
    await self.registration.unregister();
    // Do not erase other caches, unregister FCM, or reload open work forms.
  })());
});
