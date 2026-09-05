/* Repair only legacy Flutter assets. Never erase authentication or push subscriptions. */
(function (root) {
  'use strict';
  async function repair(baseUrl, env = root) {
    const base = new URL('./', baseUrl);
    const nav = env.navigator || {};
    if (nav.serviceWorker) {
      const registrations = await nav.serviceWorker.getRegistrations();
      await Promise.all(registrations.map(async (registration) => {
        const workers = [registration.active, registration.waiting, registration.installing].filter(Boolean);
        const ownLegacyWorker = workers.length > 0 && workers.every((worker) => {
          const script = new URL(worker.scriptURL);
          return script.href === new URL('flutter_service_worker.js', base).href;
        });
        if (ownLegacyWorker) await registration.unregister();
      }));
    }
    if (!env.caches) return;
    const names = await env.caches.keys();
    for (const name of names.filter((n) => /^flutter-(app-cache|temp-cache|app-manifest)$/.test(n))) {
      const cache = await env.caches.open(name);
      const requests = await cache.keys();
      await Promise.all(requests.map((request) => {
        const url = new URL(request.url);
        if (url.origin === base.origin && url.pathname.startsWith(base.pathname)) return cache.delete(request);
        return false;
      }));
    }
  }
  root.SaunaMaintenance = { repair };
  if (typeof module !== 'undefined') module.exports = { repair };
})(typeof window !== 'undefined' ? window : globalThis);
