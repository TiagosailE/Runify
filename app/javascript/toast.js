let toastCounter = 0;

window.showToast = function(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container || !message) {
    console.warn('Toast container not found or no message provided');
    return;
  }

  const toastId = `toast-${Date.now()}-${toastCounter++}`;
  const toast = document.createElement('div');
  toast.id = toastId;

  const icons = {
    success: '<i class="fas fa-check-circle"></i>',
    error: '<i class="fas fa-exclamation-circle"></i>',
    warning: '<i class="fas fa-exclamation-triangle"></i>',
    info: '<i class="fas fa-info-circle"></i>'
  };

  const colors = {
    success: 'bg-green-500',
    error: 'bg-red-500',
    warning: 'bg-yellow-500',
    info: 'bg-blue-500'
  };

  toast.className = `toast-notification ${colors[type] || colors.info} text-white px-6 py-4 rounded-xl shadow-2xl flex items-center gap-3`;
  toast.innerHTML = `
    ${icons[type] || icons.info}
    <span class="flex-1 font-medium">${message}</span>
    <button type="button" class="toast-close-button text-white hover:opacity-80 text-xl ml-2">×</button>
  `;

  toast.querySelector('.toast-close-button').addEventListener('click', () => window.closeToast(toastId));

  container.appendChild(toast);
  setTimeout(() => window.closeToast(toastId), 4000);
};

window.closeToast = (id) => {
  const toast = document.getElementById(id);
  if (!toast) return;

  toast.classList.add('toast-closing');
  setTimeout(() => toast.remove(), 300);
};
