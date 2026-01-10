window.showDeleteModal = function() {
  const modal = document.getElementById('delete-account-modal');
  if (modal) {
    modal.classList.remove('hidden');
  }
};

window.hideDeleteModal = function() {
  const modal = document.getElementById('delete-account-modal');
  if (modal) {
    modal.classList.add('hidden');
  }
};

// Debounce helper para evitar múltiplas chamadas
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

document.addEventListener('turbo:load', () => {
  const settingsPage = document.getElementById('settings-page');
  if (!settingsPage) return;

  const darkModeToggle = document.getElementById('dark-mode-toggle');
  const notificationsToggle = document.getElementById('notifications-toggle');

  if (darkModeToggle) {
    // Debounce de 500ms para evitar múltiplas chamadas
    const handleDarkModeChange = debounce(async (e) => {
      const darkMode = e.target.checked;
      
      try {
        const response = await fetch('/settings/toggle_theme', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
          },
          body: JSON.stringify({ dark_mode: darkMode })
        });
        
        if (response.ok) {
          localStorage.setItem('darkMode', darkMode ? 'true' : 'false');
          document.documentElement.classList.toggle('dark', darkMode);
        } else {
          e.target.checked = !darkMode;
          if (typeof window.showToast === 'function') {
            window.showToast('Erro ao mudar tema', 'error');
          }
        }
      } catch (error) {
        console.error('Erro:', error);
        e.target.checked = !darkMode;
        if (typeof window.showToast === 'function') {
          window.showToast('Erro ao mudar tema', 'error');
        }
      }
    }, 500);

    darkModeToggle.addEventListener('change', handleDarkModeChange);
  }

  if (notificationsToggle) {
    // Debounce de 500ms para evitar múltiplas chamadas
    const handleNotificationsChange = debounce(async (e) => {
      const enabled = e.target.checked;
      
      try {
        const response = await fetch('/settings/toggle_notifications', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
          },
          body: JSON.stringify({ enabled: enabled })
        });
        
        if (response.ok) {
        } else {
          e.target.checked = !enabled;
          if (typeof window.showToast === 'function') {
            window.showToast('Erro ao mudar notificações', 'error');
          }
        }
      } catch (error) {
        console.error('Erro:', error);
        e.target.checked = !enabled;
        if (typeof window.showToast === 'function') {
          window.showToast('Erro ao mudar notificações', 'error');
        }
      }
    }, 500);

    notificationsToggle.addEventListener('change', handleNotificationsChange);
  }
});

document.addEventListener('turbo:load', () => {
  const darkModeToggle = document.getElementById('dark-mode-toggle');
  if (darkModeToggle) {
    const isDark = document.documentElement.classList.contains('dark');
    darkModeToggle.checked = isDark;
  }
});