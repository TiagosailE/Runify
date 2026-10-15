let toastCounter = 0;

const ERROR_TOAST_DURATION = 6000;
const TOAST_DURATION = 4000;

window.showToast = function(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container || !message) {
    console.warn('Toast container not found or no message provided');
    return;
  }

  const toastId = `toast-${Date.now()}-${toastCounter++}`;
  const toast = document.createElement('div');
  toast.id = toastId;
  toast.setAttribute('role', type === 'error' ? 'alert' : 'status');

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
    <span class="flex-1 font-medium"></span>
    <button type="button" class="toast-close-button text-white hover:opacity-80 text-xl ml-2" aria-label="Fechar">×</button>
  `;
  toast.querySelector('span').textContent = message;

  toast.querySelector('.toast-close-button').addEventListener('click', () => window.closeToast(toastId));

  container.appendChild(toast);
  setTimeout(() => window.closeToast(toastId), type === 'error' ? ERROR_TOAST_DURATION : TOAST_DURATION);
};

window.closeToast = (id) => {
  const toast = document.getElementById(id);
  if (!toast) return;

  toast.classList.add('toast-closing');
  setTimeout(() => toast.remove(), 300);
};

// O layout guarda aqui os toasts que chegam antes deste módulo carregar.
(window.pendingToasts || []).forEach((toast) => window.showToast(toast.message, toast.type));
window.pendingToasts = [];

// Formulário ou navegação pelo Turbo sem resposta do servidor (sem internet,
// servidor fora do ar): sem isto a página só fica parada.
document.addEventListener('turbo:fetch-request-error', () => {
  window.showToast('Sem conexão com o servidor. Verifique sua internet e tente de novo.', 'error');
});
