let state = {
  genres: [{ id: null, name: 'Tous' }],
  categories: [{ id: null, name: 'Toutes' }],
  selectedGenreId: null,
  selectedCategoryId: null,
  selectedSmartSection: null,
  searchQuery: '',
  favoriteIds: new Set(),
  downloadedIds: new Set(),
  books: [],
};

const resultsArea = document.getElementById('results-area');
const genreRow = document.getElementById('genre-row');
const categoryRow = document.getElementById('category-row');
const smartSectionRow = document.getElementById('smart-section-row');
const searchInput = document.getElementById('search-input');
const accountBtn = document.getElementById('account-btn');

let searchDebounce = null;

document.addEventListener('DOMContentLoaded', bootstrap);

async function bootstrap() {
  accountBtn.textContent = isLoggedIn() ? '🚪' : '👤';
  accountBtn.title = isLoggedIn() ? 'Se déconnecter' : 'Se connecter';
  accountBtn.addEventListener('click', () => {
    if (isLoggedIn()) {
      apiLogout();
      window.location.reload();
    } else {
      window.location.href = 'login.html';
    }
  });

  searchInput.addEventListener('input', () => {
    state.searchQuery = searchInput.value;
    clearTimeout(searchDebounce);
    searchDebounce = setTimeout(refreshBooks, 300);
  });

  smartSectionRow.addEventListener('click', (event) => {
    const btn = event.target.closest('button[data-section]');
    if (!btn) return;
    const section = btn.dataset.section;
    state.selectedSmartSection = state.selectedSmartSection === section ? null : section;
    renderSmartSections();
    refreshBooks();
  });

  try {
    const [genres, categories, favoriteIds, downloadedIds] = await Promise.all([
      fetchGenres(),
      fetchCategories(),
      fetchFavoriteIds(),
      listOfflineIds(),
    ]);
    state.genres = [{ id: null, name: 'Tous' }, ...genres];
    state.categories = [{ id: null, name: 'Toutes' }, ...categories];
    state.favoriteIds = new Set(favoriteIds);
    state.downloadedIds = new Set(downloadedIds);
    renderGenreRow();
    renderCategoryRow();
    renderSmartSections();
    await refreshBooks();
  } catch (err) {
    resultsArea.innerHTML = `<div class="error-state">Impossible de joindre le serveur : ${escapeHtml(err.message)}</div>`;
  }
}

function renderGenreRow() {
  renderFilterRow(genreRow, state.genres, state.selectedGenreId, (id) => {
    state.selectedGenreId = id;
    renderGenreRow();
    refreshBooks();
  });
}

function renderCategoryRow() {
  renderFilterRow(categoryRow, state.categories, state.selectedCategoryId, (id) => {
    state.selectedCategoryId = id;
    renderCategoryRow();
    refreshBooks();
  });
}

function renderFilterRow(container, items, selectedId, onSelect) {
  container.innerHTML = '';
  items.forEach((item) => {
    const btn = document.createElement('button');
    btn.className = 'chip' + (item.id === selectedId ? ' active' : '');
    btn.textContent = item.name;
    btn.addEventListener('click', () => onSelect(item.id === selectedId ? null : item.id));
    container.appendChild(btn);
  });
}

function renderSmartSections() {
  smartSectionRow.querySelectorAll('button[data-section]').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.section === state.selectedSmartSection);
  });
}

async function refreshBooks() {
  resultsArea.innerHTML = `
    <div class="loading-state">
      <div class="spinner"></div>
      Chargement des livres...
    </div>`;
  try {
    let sortBy = null;
    if (state.selectedSmartSection === 'Nouveautés') sortBy = 'newest';
    if (state.selectedSmartSection === 'Les plus lus') sortBy = 'popular';

    let books = await fetchBooks({
      genreId: state.selectedGenreId,
      categoryId: state.selectedCategoryId,
      search: state.searchQuery,
      sortBy,
    });

    if (state.selectedSmartSection === 'Favoris') {
      books = books.filter((b) => state.favoriteIds.has(b.id));
    } else if (state.selectedSmartSection === 'Téléchargés') {
      books = books.filter((b) => state.downloadedIds.has(b.id));
    }

    state.books = books;
    renderBooks();
  } catch (err) {
    resultsArea.innerHTML = `<div class="error-state">Erreur de chargement des livres : ${escapeHtml(err.message)}</div>`;
  }
}

function renderBooks() {
  if (state.books.length === 0) {
    resultsArea.innerHTML = `<div class="empty-state">Aucun livre ne correspond à votre recherche.</div>`;
    return;
  }

  const grid = document.createElement('div');
  grid.className = 'book-grid';

  state.books.forEach((book) => {
    const isFav = state.favoriteIds.has(book.id);
    const isDownloaded = state.downloadedIds.has(book.id);
    const coverUrl = bookCoverUrl(book.cover_filename);

    const card = document.createElement('button');
    card.className = 'book-card';
    card.innerHTML = `
      <div class="book-cover" style="${coverUrl ? `background-image:url('${coverUrl}')` : ''}">
        ${coverUrl ? '' : '📖'}
        <button class="badge badge-fav ${isFav ? 'active' : ''}" data-action="favorite" title="Favori">
          ${isFav ? '❤️' : '🤍'}
        </button>
        ${isDownloaded ? '<span class="badge badge-downloaded" title="Disponible hors-ligne">⬇️</span>' : ''}
      </div>
      <p class="book-title">${escapeHtml(book.title)}</p>
      <p class="book-author">${escapeHtml(book.author)}</p>
    `;

    card.querySelector('[data-action="favorite"]').addEventListener('click', (event) => {
      event.stopPropagation();
      toggleFavorite(book.id);
    });
    card.addEventListener('click', () => {
      window.location.href = `reader.html?id=${book.id}`;
    });

    grid.appendChild(card);
  });

  resultsArea.innerHTML = '';
  resultsArea.appendChild(grid);
}

async function toggleFavorite(bookId) {
  if (!isLoggedIn()) {
    window.location.href = 'login.html';
    return;
  }
  const isFav = state.favoriteIds.has(bookId);
  isFav ? state.favoriteIds.delete(bookId) : state.favoriteIds.add(bookId);
  renderBooks();
  try {
    if (isFav) {
      await removeFavorite(bookId);
    } else {
      await addFavorite(bookId);
    }
    if (state.selectedSmartSection === 'Favoris') await refreshBooks();
  } catch {
    // Réseau indisponible : on annule le changement optimiste.
    isFav ? state.favoriteIds.add(bookId) : state.favoriteIds.delete(bookId);
    renderBooks();
  }
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}
