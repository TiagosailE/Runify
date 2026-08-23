window.showLogoutModal = function() {
  const modal = document.getElementById('logout-modal');
  if (modal) {
    modal.classList.remove('hidden');
  }
};

window.hideLogoutModal = function() {
  const modal = document.getElementById('logout-modal');
  if (modal) {
    modal.classList.add('hidden');
  }
};

window.confirmLogout = function() {
  const form = document.getElementById('logout-form');
  if (form) {
    form.submit();
  }
};

document.addEventListener('turbo:load', () => {
  const modal = document.getElementById('logout-modal');

  if (modal) {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        window.hideLogoutModal();
      }
    });
  }

  const openButton = document.getElementById('logout-open-button');
  if (openButton) {
    openButton.addEventListener('click', () => window.showLogoutModal());
  }

  const cancelButton = document.getElementById('logout-cancel');
  if (cancelButton) {
    cancelButton.addEventListener('click', () => window.hideLogoutModal());
  }

  const confirmButton = document.getElementById('logout-confirm');
  if (confirmButton) {
    confirmButton.addEventListener('click', () => window.confirmLogout());
  }

  const avatarInput = document.getElementById('avatar-input');
  if (avatarInput) {
    avatarInput.addEventListener('change', (event) => {
      const file = event.target.files[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = (e) => {
        const preview = document.getElementById('avatar-preview');
        if (preview) preview.src = e.target.result;
      };
      reader.readAsDataURL(file);
    });
  }
});