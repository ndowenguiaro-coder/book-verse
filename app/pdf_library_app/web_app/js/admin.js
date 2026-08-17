document.addEventListener('DOMContentLoaded', async () => {
  const authWarning = document.getElementById('auth-warning');
  const forms = document.querySelectorAll('#genre-form, #category-form, #book-form');

  if (!isLoggedIn()) {
    authWarning.hidden = false;
    forms.forEach((form) => form.querySelectorAll('input, select, button').forEach((el) => (el.disabled = true)));
    return;
  }

  const genreForm = document.getElementById('genre-form');
  const genreNameInput = document.getElementById('genre-name');
  const genreStatus = document.getElementById('genre-status');
  const genreList = document.getElementById('genre-list');

  const categoryForm = document.getElementById('category-form');
  const categoryNameInput = document.getElementById('category-name');
  const categoryStatus = document.getElementById('category-status');
  const categoryList = document.getElementById('category-list');

  const bookForm = document.getElementById('book-form');
  const bookGenreSelect = document.getElementById('book-genre');
  const bookCategorySelect = document.getElementById('book-category');
  const bookStatus = document.getElementById('book-status');
  const bookSubmitBtn = document.getElementById('book-submit-btn');

  async function refreshGenres() {
    const genres = await fetchGenres();
    genreList.innerHTML = genres.map((g) => `<span class="tag-pill">${escapeHtml(g.name)}</span>`).join('');
    bookGenreSelect.innerHTML = genres
      .map((g) => `<option value="${g.id}">${escapeHtml(g.name)}</option>`)
      .join('');
  }

  async function refreshCategories() {
    const categories = await fetchCategories();
    categoryList.innerHTML = categories.map((c) => `<span class="tag-pill">${escapeHtml(c.name)}</span>`).join('');
    bookCategorySelect.innerHTML = categories
      .map((c) => `<option value="${c.id}">${escapeHtml(c.name)}</option>`)
      .join('');
  }

  genreForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    setStatus(genreStatus, '', null);
    try {
      await createGenre(genreNameInput.value.trim());
      genreNameInput.value = '';
      await refreshGenres();
      setStatus(genreStatus, 'Genre ajouté.', 'success');
    } catch (err) {
      setStatus(genreStatus, err.message, 'error');
    }
  });

  categoryForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    setStatus(categoryStatus, '', null);
    try {
      await createCategory(categoryNameInput.value.trim());
      categoryNameInput.value = '';
      await refreshCategories();
      setStatus(categoryStatus, 'Catégorie ajoutée.', 'success');
    } catch (err) {
      setStatus(categoryStatus, err.message, 'error');
    }
  });

  bookForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    setStatus(bookStatus, '', null);

    const pdfFile = document.getElementById('book-pdf').files[0];
    if (!pdfFile) {
      setStatus(bookStatus, 'Merci de sélectionner un fichier PDF.', 'error');
      return;
    }

    const formData = new FormData();
    formData.append('title', document.getElementById('book-title').value.trim());
    formData.append('author', document.getElementById('book-author').value.trim());
    formData.append('description', document.getElementById('book-description').value.trim());
    formData.append('genre_id', bookGenreSelect.value);
    formData.append('category_id', bookCategorySelect.value);
    formData.append('pdf_file', pdfFile);
    const coverFile = document.getElementById('book-cover').files[0];
    if (coverFile) formData.append('cover_file', coverFile);

    bookSubmitBtn.disabled = true;
    bookSubmitBtn.textContent = 'Publication en cours...';
    try {
      await createBook(formData);
      bookForm.reset();
      setStatus(bookStatus, 'Livre publié ! Il est déjà visible dans la bibliothèque.', 'success');
    } catch (err) {
      setStatus(bookStatus, err.message, 'error');
    } finally {
      bookSubmitBtn.disabled = false;
      bookSubmitBtn.textContent = 'Publier le livre';
    }
  });

  function setStatus(el, message, kind) {
    el.textContent = message;
    el.className = 'status-msg' + (kind ? ` ${kind}` : '');
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str ?? '';
    return div.innerHTML;
  }

  try {
    await Promise.all([refreshGenres(), refreshCategories()]);
  } catch (err) {
    setStatus(bookStatus, `Erreur de chargement : ${err.message}`, 'error');
  }
});
