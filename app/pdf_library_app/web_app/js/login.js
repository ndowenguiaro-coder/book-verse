document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('auth-form');
  if (!form) return;

  // Un token existant doit être validé par le backend, pas seulement par localStorage.
  if (await ensureSession()) {
    window.location.replace('library.html');
    return;
  }

  let isRegisterMode = false;

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

  function showError(message) {
    errorBox.textContent = message;
    errorBox.hidden = false;
  }

  function applyMode() {
    title.textContent = isRegisterMode ? 'Créer un compte' : 'Bienvenue';
    submitBtn.textContent = isRegisterMode ? 'Créer mon compte' : 'Connexion';
    switchText.textContent = isRegisterMode ? 'Déjà un compte ?' : 'Pas encore de compte ?';
    switchBtn.textContent = isRegisterMode ? 'Se connecter' : 'En créer un';
    nameField.hidden = !isRegisterMode;
    confirmField.hidden = !isRegisterMode;
    nameInput.required = false;
    confirmInput.required = isRegisterMode;
    passwordInput.autocomplete = isRegisterMode ? 'new-password' : 'current-password';
    errorBox.hidden = true;
  }

  switchBtn.addEventListener('click', () => {
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

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      showError('Entre une adresse e-mail valide.');
      return;
    }
    if (password.length < 8) {
      showError('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (isRegisterMode && password !== confirmation) {
      showError('Les deux mots de passe ne correspondent pas.');
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = isRegisterMode ? 'Création…' : 'Connexion…';

    try {
      if (isRegisterMode) {
        await apiRegister(email, password, nameInput.value);
      }
      await apiLogin(email, password);
      window.location.replace('library.html');
    } catch (error) {
      showError(error.message || 'Une erreur est survenue.');
      submitBtn.disabled = false;
      applyMode();
    }
  });

  applyMode();
});
