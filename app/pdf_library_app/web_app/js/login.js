document.addEventListener('DOMContentLoaded', () => {
  // Déjà connecté : on saute directement à la bibliothèque.
  if (isLoggedIn()) {
    window.location.href = 'library.html';
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
    isRegisterMode = !isRegisterMode;
    applyMode();
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    errorBox.hidden = true;

    const email = emailInput.value.trim();
    const password = passwordInput.value;
    const confirmation = confirmInput.value;

    if (!email.includes('@')) {
      showError('Email invalide.');
      return;
    }
    if (password.length < 8) {
      showError('Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (isRegisterMode && password !== confirmation) {
      showError('Les mots de passe ne correspondent pas.');
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = '…';
    try {
      if (isRegisterMode) {
        await apiRegister(email, password, nameInput.value.trim());
        await apiLogin(email, password);
      } else {
        await apiLogin(email, password);
      }
      window.location.href = 'library.html';
    } catch (err) {
      showError(err.message);
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
