self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const url = event.request.url;
  if (url.startsWith('https://www.gstatic.com/firebasejs/')) {
    const parts = url.split('/');
    const version = parts[parts.length - 2];
    const filename = parts[parts.length - 1];
    
    // Rewrite CDN request to local path
    const localUrl = `/firebase-sdk/${version}/${filename}`;
    
    console.log(`[Firebase SW] Intercepted CDN request: ${url} -> Serving from local: ${localUrl}`);
    event.respondWith(
      fetch(localUrl).catch(err => {
        console.error(`[Firebase SW] Failed to fetch local file ${localUrl}:`, err);
        return fetch(event.request);
      })
    );
  }
});
