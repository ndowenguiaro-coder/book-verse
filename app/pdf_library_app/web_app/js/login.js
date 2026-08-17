document.addEventListener('DOMContentLoaded', async () => {
  // Never trust a stale localStorage token for navigation.
  if (await requireValidSession()) {
    window.location.replace('library.html');
    return;
  }

  let isRegisterMode = false;

  const form = document.getElementById('auth-form');
  const title = document.getElementById('form-title');
  const nameField = document.getElementById('name-field');
  const nameInput = document.getElementById('name');
  const emailInput = document.getElementById('email');
  const passwordInput = document.getElementById('password');
  const confirmField = document.getElementById('confirm-field');
  const confirmInput = document.getElementById('confirm-password');
  const errorBox = document.getElementById('form-error');
  const submitBtn = document.getElementById('submit-btn');
  const switchText = document.getElementById('switch-text');
  const switchBtn = document.getElementById('switch-btn');

  function applyMode() {
    title.textContent = isRegisterMode ? 'Créer un compte' : 'Bienvenue';
    submitBtn.textContent = isRegisterMode ? 'Créer mon compte' : 'Connexion';
    switchText.textContent = isRegisterMode ? 'Déjà un compte ?' : 'Pas encore de compte ?';
    switchBtn.textContent = isRegisterMode ? 'Se connecter' : 'En créer un';
    nameField.hidden = !isRegisterMode;
    confirmField.hidden = !isRegisterMode;
    confirmInput.required = isRegisterMode;
    passwordInput.autocomplete = isRegisterMode ? 'new-password' : 'current-password';
    errorBox.hidden = true;
  }

  switchBtn.addEventListener('click', () => {
    if (submitBtn.disabled) return;
    isRegisterMode = !isRegisterMode;
    form.reset();
    applyMode();
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    errorBox.hidden = true;

    const email = emailInput.value.trim().toLowerCase();
    const password = passwordInput.value;
    const confirmation = confirmInput.value;
    const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

    if (!emailOk) return showError('Adresse e-mail invalide.');
    if (password.length < 8) return showError('Le mot de passe doit contenir au moins 8 caractères.');
    if (isRegisterMode && password !== confirmation) return showError('Les mots de passe ne correspondent pas.');

    submitBtn.disabled = true;
    submitBtn.textContent = isRegisterMode ? 'Création…' : 'Connexion…';
    try {
      if (isRegisterMode) {
        await apiRegister(email, password, nameInput.value.trim());
      }
      await apiLogin(email, password);
      window.location.replace('library.html');
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      showError(message.includes('Failed to fetch')
        ? 'Impossible de joindre le serveur. Vérifie l’URL du backend FastAPI et la configuration Vercel.'
        : message);
      submitBtn.disabled = false;
      applyMode();
    }
  });

  function showError(message) {
    errorBox.textContent = message;
    errorBox.hidden = false;
  }

  applyMode();
});
