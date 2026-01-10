let toastCounter = 0;

window.showToast = function(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container || !message) return;

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
  
  const existingToasts = container.children.length;
  toast.style.cssText = `
    position: fixed; 
    top: ${20 + existingToasts * 80}px; 
    left: 50%; 
    transform: translateX(-50%); 
    max-width: calc(100vw - 40px); 
    width: 90%; 
    z-index: 99999;
    animation: slideInFromTop 0.3s ease-out;
  `;
  
  toast.className = `${colors[type] || colors.info} text-white px-6 py-4 rounded-xl shadow-2xl flex items-center gap-3`;
  toast.innerHTML = `
    ${icons[type] || icons.info}
    <span class="flex-1 font-medium">${message}</span>
    <button onclick="window.closeToast('${toastId}')" class="text-white hover:opacity-80 text-xl ml-2">×</button>
  `;
  
  container.appendChild(toast);
  setTimeout(() => window.closeToast(toastId), 4000);
};

window.closeToast = (id) => {
  const toast = document.getElementById(id);
  if (!toast) return;
  
  toast.style.animation = 'slideOutToTop 0.3s ease-in';
  setTimeout(() => toast.remove(), 300);
};

const style = document.createElement('style');
style.textContent = `
  @keyframes slideInFromTop {
    from {
      opacity: 0;
      transform: translateX(-50%) translateY(-100%);
    }
    to {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
  }
  
  @keyframes slideOutToTop {
    from {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
    to {
      opacity: 0;
      transform: translateX(-50%) translateY(-100%);
    }
  }
`;
document.head.appendChild(style);