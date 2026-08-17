/*
 * BookVerse - configuration API
 *
 * PRIORITÉ :
 * 1) window.BOOKVERSE_API_URL (utile pour Vercel / hébergement séparé)
 * 2) <meta name="bookverse-api-url" content="..."> dans la page
 * 3) localStorage (utile pour tester sans reconstruire le site)
 * 4) l'origine actuelle (utile quand FastAPI sert aussi le site)
 */
(function () {
  const explicit = typeof window.BOOKVERSE_API_URL === 'string'
    ? window.BOOKVERSE_API_URL.trim()
    : '';

  const meta = document
    .querySelector('meta[name="bookverse-api-url"]')
    ?.getAttribute('content')
    ?.trim() || '';

  const saved = localStorage.getItem('bookverse_api_url')?.trim() || '';

  const base = explicit || meta || saved || window.location.origin;
  window.BOOKVERSE_API_URL = base.replace(/\/+$/, '');

  // Permet de changer l'API depuis la console sans modifier les autres fichiers.
  window.setBookVerseApiUrl = function (url) {
    const normalized = String(url || '').trim().replace(/\/+$/, '');
    if (!normalized) {
      localStorage.removeItem('bookverse_api_url');
      window.BOOKVERSE_API_URL = window.location.origin;
      return window.BOOKVERSE_API_URL;
    }
    localStorage.setItem('bookverse_api_url', normalized);
    window.BOOKVERSE_API_URL = normalized;
    return normalized;
  };
})();

const API_BASE_URL = window.BOOKVERSE_API_URL;
