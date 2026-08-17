// Toute la communication avec le backend FastAPI passe par ce module.
// Le jeton JWT est stocké dans localStorage (équivalent du token sécurisé
// côté mobile) et rejoué automatiquement sur les routes protégées.

const TOKEN_KEY = 'bookverse_token';

function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

function setToken(token) {
  localStorage.setItem(TOKEN_KEY, token);
}

function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

async function ensureSession() {
  const token = getToken();
  if (!token) return false;
  try {
    const response = await fetch(`${API_BASE_URL}/auth/me`, { headers: authHeaders() });
    if (response.ok) return true;
  } catch {}
  clearToken();
  return false;
}

function isLoggedIn() { return Boolean(getToken()); }

function authHeaders() {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function extractError(response) {
  try {
    const data = await response.json();
    return data.detail || `Erreur inconnue (${response.status}).`;
  } catch {
    return `Erreur inconnue (${response.status}).`;
  }
}

// --- AUTHENTIFICATION ---

async function apiRegister(email, password, displayName) {
  const response = await fetch(`${API_BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, display_name: displayName || null }),
  });
  if (!response.ok) throw new Error(await extractError(response));
}

async function apiLogin(email, password) {
  const response = await fetch(`${API_BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!response.ok) throw new Error(await extractError(response));
  const data = await response.json();
  setToken(data.access_token);
}

function apiLogout() {
  clearToken();
}

// --- GENRES & CATÉGORIES ---

async function fetchGenres() {
  const response = await fetch(`${API_BASE_URL}/genres/`);
  if (!response.ok) throw new Error('Impossible de charger les genres.');
  return response.json();
}

async function fetchCategories() {
  const response = await fetch(`${API_BASE_URL}/categories/`);
  if (!response.ok) throw new Error('Impossible de charger les catégories.');
  return response.json();
}

async function createGenre(name) {
  const response = await fetch(`${API_BASE_URL}/genres/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify({ name }),
  });
  if (!response.ok) throw new Error(await extractError(response));
  return response.json();
}

async function createCategory(name) {
  const response = await fetch(`${API_BASE_URL}/categories/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify({ name }),
  });
  if (!response.ok) throw new Error(await extractError(response));
  return response.json();
}

async function createBook(formData) {
  // Ne jamais fixer 'Content-Type' à la main avec FormData : le navigateur
  // doit générer lui-même la frontière multipart, sinon l'upload échoue.
  const response = await fetch(`${API_BASE_URL}/books/`, {
    method: 'POST',
    headers: { ...authHeaders() },
    body: formData,
  });
  if (!response.ok) throw new Error(await extractError(response));
  return response.json();
}

// --- LIVRES ---

async function fetchBooks({ genreId, categoryId, search, sortBy } = {}) {
  const params = new URLSearchParams();
  if (genreId) params.set('genre_id', genreId);
  if (categoryId) params.set('category_id', categoryId);
  if (search) params.set('search', search);
  if (sortBy) params.set('sort_by', sortBy);

  const response = await fetch(`${API_BASE_URL}/books/?${params.toString()}`);
  if (!response.ok) throw new Error('Impossible de charger les livres.');
  return response.json();
}

async function fetchBook(bookId) {
  const response = await fetch(`${API_BASE_URL}/books/${bookId}`);
  if (!response.ok) throw new Error('Livre introuvable.');
  return response.json();
}

async function registerView(bookId) {
  try {
    await fetch(`${API_BASE_URL}/books/${bookId}/view`, { method: 'PATCH' });
  } catch {
    // Non bloquant : une vue non comptabilisée n'empêche pas la lecture.
  }
}

function bookPdfUrl(bookId) {
  return `${API_BASE_URL}/books/${bookId}/download`;
}

function bookCoverUrl(coverFilename) {
  return coverFilename ? `${API_BASE_URL}/static/covers/${coverFilename}` : null;
}

// --- FAVORIS (nécessitent une connexion) ---

async function fetchFavoriteIds() {
  if (!isLoggedIn()) return [];
  const response = await fetch(`${API_BASE_URL}/favorites/`, { headers: authHeaders() });
  if (!response.ok) return [];
  const books = await response.json();
  return books.map((b) => b.id);
}

async function addFavorite(bookId) {
  const response = await fetch(`${API_BASE_URL}/favorites/?book_id=${bookId}`, {
    method: 'POST',
    headers: authHeaders(),
  });
  if (!response.ok) throw new Error(await extractError(response));
}

async function removeFavorite(bookId) {
  await fetch(`${API_BASE_URL}/favorites/${bookId}`, {
    method: 'DELETE',
    headers: authHeaders(),
  });
}

// --- PROGRESSION DE LECTURE (nécessite une connexion) ---

async function saveReadingProgress(bookId, currentPage) {
  if (!isLoggedIn()) return;
  try {
    await fetch(`${API_BASE_URL}/books/${bookId}/progress`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ current_page: currentPage }),
    });
  } catch {
    // Échec silencieux : la progression sera resynchronisée à la prochaine ouverture.
  }
}

async function fetchReadingProgress(bookId) {
  if (!isLoggedIn()) return null;
  try {
    const response = await fetch(`${API_BASE_URL}/books/${bookId}/progress`, { headers: authHeaders() });
    if (!response.ok) return null;
    const data = await response.json();
    return data ? data.current_page : null;
  } catch {
    return null;
  }
}
