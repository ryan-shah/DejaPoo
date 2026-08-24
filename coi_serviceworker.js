// coi_serviceworker.js — Cross-Origin Isolation for GitHub Pages
// GitHub Pages cannot send Cross-Origin-Opener-Policy / Cross-Origin-Embedder-Policy
// response headers, so the page is never cross-origin isolated and drift (sqlite3
// WASM) falls back to IndexedDB instead of OPFS. This service worker intercepts
// same-origin fetches and rewrites the response headers so the browser treats the
// page as cross-origin isolated, unlocking OPFS + SharedArrayBuffer support.
//
// Only takes effect when the page is not already cross-origin isolated (e.g. a
// dev server that already sends the headers won't be double-processed).

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', function (event) {
  // Once the worker itself is cross-origin isolated there is nothing left to fix up.
  if (self.crossOriginIsolated) {
    return;
  }

  if (event.request.cache === 'only-if-cached' && event.request.mode !== 'same-origin') {
    return;
  }

  event.respondWith(
    fetch(event.request).then(function (response) {
      if (response.status === 0) {
        return response;
      }

      const headers = new Headers(response.headers);
      headers.set('Cross-Origin-Embedder-Policy', 'credentialless');
      headers.set('Cross-Origin-Opener-Policy', 'same-origin');

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: headers,
      });
    })
  );
});
