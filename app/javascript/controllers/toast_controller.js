import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    message: String,
    type: String,
    duration: { type: Number, default: 3000 }
  }

  connect() {
    if (this.hasMessageValue) {
      this.show()
    }
  }

  show() {
    setTimeout(() => {
      this.element.classList.remove('translate-y-[-200%]', 'opacity-0')
      this.element.classList.add('translate-y-0', 'opacity-100')
    }, 100)

    setTimeout(() => {
      this.hide()
    }, this.durationValue)
  }

  hide() {
    this.element.classList.remove('translate-y-0', 'opacity-100')
    this.element.classList.add('translate-y-[-200%]', 'opacity-0')
    
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  close() {
    this.hide()
  }
}

window.showToast = function(message, type = 'success', duration = 3000) {
  const toastContainer = document.getElementById('toast-container')
  if (!toastContainer) return

  const icons = {
    success: '<i class="fas fa-check-circle text-green-500"></i>',
    error: '<i class="fas fa-exclamation-circle text-red-500"></i>',
    info: '<i class="fas fa-info-circle text-blue-500"></i>',
    warning: '<i class="fas fa-exclamation-triangle text-yellow-500"></i>'
  }

  const colors = {
    success: 'bg-green-50 border-green-200',
    error: 'bg-red-50 border-red-200',
    info: 'bg-blue-50 border-blue-200',
    warning: 'bg-yellow-50 border-yellow-200'
  }

  const toast = document.createElement('div')
  toast.setAttribute('data-controller', 'toast')
  toast.setAttribute('data-toast-duration-value', duration)
  toast.className = `fixed top-20 left-1/2 transform -translate-x-1/2 translate-y-[-200%] opacity-0 z-50 transition-all duration-300 ease-out`
  
  toast.innerHTML = `
    <div class="${colors[type]} border-2 rounded-2xl px-6 py-4 shadow-lg flex items-center gap-3 min-w-[300px] max-w-[500px]">
      ${icons[type]}
      <p class="text-gray-900 font-medium flex-1">${message}</p>
      <button data-action="click->toast#close" class="text-gray-400 hover:text-gray-600 transition-colors">
        <i class="fas fa-times"></i>
      </button>
    </div>
  `

  toastContainer.appendChild(toast)
}