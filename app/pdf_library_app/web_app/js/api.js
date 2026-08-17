// BookVerse Web API client.
// config.js doit être chargé avant ce fichier.

const TOKEN_KEY = 'bookverse_token';

function apiUrl(path) {
  const base = String(window.BOOKVERSE_API_URL || '').replace(/\/+$/, '');
  const cleanPath = String(path || '').startsWith('/') ? path : `/${path}`;
  return `${base}${cleanPath}`;
}

function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

function setToken(token) {
  if (!token) throw new Error('Le serveur n’a pas fourni de jeton de connexion.');
  localStorage.setItem(TOKEN_KEY, token);
}

function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

function isLoggedIn() {
  return Boolean(getToken());
}

function authHeaders() {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function extractError(response) {
  let data = null;
  try { data = await response.json(); } catch (_) {}

  if (data?.detail) {
    if (Array.isArray(data.detail)) {
      return data.detail.map((item) => item.msg || 'Donnée invalide.').join(' ');
    }
    return String(data.detail);
  }

  return `Le serveur a répondu ${response.status}${response.statusText ? ` (${response.statusText})` : ''}.`;
}

async function request(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  const token = getToken();
  if (token && !headers.Authorization) headers.Authorization = `Bearer ${token}`;

  let response;
  try {
    response = await fetch(apiUrl(path), {
      ...options,
      headers,
      credentials: 'omit',
    });
  } catch (error) {
    throw new Error(
      `Impossible de joindre BookVerse API (${apiUrl(path)}). ` +
      `Vérifie que le backend est démarré et que l'URL API est correcte.`
    );
  }

  if (response.status === 401) {
    clearToken();
  }

  if (!response.ok) throw new Error(await extractError(response));
  return response;
}

async function ensureSession() {
  if (!getToken()) return false;
  try {
    await request('/auth/me');
    return true;
  } catch (_) {
    clearToken();
    return false;
  }
}

// --- AUTHENTIFICATION ---

async function apiRegister(email, password, displayName) {
  const response = await request('/auth/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: email.trim().toLowerCase(),
      password,
      display_name: displayName?.trim() || null,
    }),
  });
  return response.json();
}

async function apiLogin(email, password) {
  const response = await request('/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: email.trim().toLowerCase(), password }),
  });
  const data = await response.json();
  setToken(data.access_token);
  return data;
}

function apiLogout() {
  clearToken();
}

// --- GENRES & CATÉGORIES ---
async function fetchGenres() {
  const response = await request('/genres/');
  return response.json();
}

async function fetchCategories() {
  const response = await request('/categories/');
  return response.json();
}

async function createGenre(name) {
  const response = await request('/genres/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name }),
  });
  return response.json();
}

async function createCategory(name) {
  const response = await request('/categories/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name }),
  });
  return response.json();
}

async function createBook(formData) {
  const response = await request('/books/', { method: 'POST', body: formData });
  return response.json();
}

// --- LIVRES ---
async function fetchBooks({ genreId, categoryId, search, sortBy } = {}) {
  const params = new URLSearchParams();
  if (genreId) params.set('genre_id', genreId);
  if (categoryId) params.set('category_id', categoryId);
  if (search) params.set('search', search);
  if (sortBy) params.set('sort_by', sortBy);

  const response = await request(`/books/?${params.toString()}`);
  return response.json();
}

async function fetchBook(bookId) {
  const response = await request(`/books/${bookId}`);
  return response.json();
}

async function registerView(bookId) {
  try { await request(`/books/${bookId}/view`, { method: 'PATCH' }); } catch (_) {}
}

function bookPdfUrl(bookId) {
  return apiUrl(`/books/${bookId}/download`);
}

function bookCoverUrl(coverFilename) {
  return coverFilename ? apiUrl(`/static/covers/${encodeURIComponent(coverFilename)}`) : null;
}

// --- FAVORIS ---
async function fetchFavoriteIds() {
  if (!isLoggedIn()) return [];
  try {
    const response = await request('/favorites/');
    const books = await response.json();
    return books.map((book) => book.id);
  } catch (_) { return []; }
}

async function addFavorite(bookId) {
  await request(`/favorites/?book_id=${encodeURIComponent(bookId)}`, { method: 'POST' });
}

async function removeFavorite(bookId) {
  await request(`/favorites/${encodeURIComponent(bookId)}`, { method: 'DELETE' });
}

// --- PROGRESSION ---
async function saveReadingProgress(bookId, currentPage) {
  if (!isLoggedIn()) return;
  try {
    await request(`/books/${bookId}/progress`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ current_page: currentPage }),
    });
  } catch (_) {}
}

async function fetchReadingProgress(bookId) {
  if (!isLoggedIn()) return null;
  try {
    const response = await request(`/books/${bookId}/progress`);
    const data = await response.json();
    return data ? data.current_page : null;
  } catch (_) { return null; }
}
