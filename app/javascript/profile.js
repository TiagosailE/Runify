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
});