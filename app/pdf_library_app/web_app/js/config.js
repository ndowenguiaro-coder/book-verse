// BookVerse API configuration.
//
// Priority:
// 1) window.BOOKVERSE_API_URL (optional runtime override)
// 2) local development: http://127.0.0.1:8000
// 3) production: /api (only if Vercel is configured to proxy /api to the
//    real FastAPI backend). If your backend has a separate public URL,
//    set window.BOOKVERSE_API_URL before loading api.js.
(function () {
  const runtime = (window.BOOKVERSE_API_URL || '').trim().replace(/\/$/, '');
  const host = window.location.hostname;
  const isLocal = host === 'localhost' || host === '127.0.0.1';

  window.BOOKVERSE_API_BASE_URL = runtime || (isLocal ? 'http://127.0.0.1:8000' : '/api');
})();

const API_BASE_URL = window.BOOKVERSE_API_BASE_URL;
