window.showToast = function(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container) return;

  const toastId = `toast-${Date.now()}`;
  const toastEl = document.createElement('div');
  toastEl.id = toastId;

  const colors = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
    warning: 'bg-yellow-500 text-white',
    info: 'bg-blue-500 text-white'
  };

  const colorClass = colors[type] || colors.info;

  toastEl.className = `
    ${colorClass}
    px-6 py-4 rounded-lg shadow-lg
    fixed bottom-6 right-6 max-w-md
    animate-slide-in-up
    flex items-center justify-between gap-4
    z-50
  `;

  toastEl.innerHTML = `
    <span>${message}</span>
    <button onclick="closeToast('${toastId}')" class="text-white hover:opacity-80 font-bold text-lg">
      ×
    </button>
  `;

  container.appendChild(toastEl);

  const timeout = setTimeout(() => closeToast(toastId), 4000);

  toastEl.dataset.timeout = timeout;
};

window.closeToast = function(toastId) {
  const toast = document.getElementById(toastId);
  if (!toast) return;

  if (toast.dataset.timeout) {
    clearTimeout(parseInt(toast.dataset.timeout));
  }

  toast.classList.add('animate-fade-out');
  
  setTimeout(() => {
    toast.remove();
  }, 300);
};

const style = document.createElement('style');
style.textContent = `
  @keyframes slideInUp {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes fadeOut {
    from {
      opacity: 1;
      transform: translateY(0);
    }
    to {
      opacity: 0;
      transform: translateY(20px);
    }
  }

  .animate-slide-in-up {
    animation: slideInUp 0.3s ease-out;
  }

  .animate-fade-out {
    animation: fadeOut 0.3s ease-out;
  }
`;
document.head.appendChild(style);
