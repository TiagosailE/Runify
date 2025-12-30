import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "message", "spinner"]

  connect() {
    this.messages = [
      "Analisando seu histórico...",
      "Calculando volume semanal...",
      "Definindo dias de descanso...",
      "Estruturando os intervalados...",
      "Ajustando as zonas de pace...",
      "Finalizando seu plano..."
    ]
  }

  submit(event) {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
      this.modalTarget.classList.add('flex')
    }

    this.startMessageRotation()
    const form = event.target
    const submitButton = form.querySelector('button[type="submit"], input[type="submit"]')
    
    if (submitButton) {
      submitButton.classList.add('opacity-50', 'cursor-not-allowed')
      setTimeout(() => {
        submitButton.disabled = true
      }, 50)
    }
  }

  startMessageRotation() {
    let index = 0
    if (this.messageTarget) this.messageTarget.textContent = this.messages[0]

    this.interval = setInterval(() => {
      if (this.messageTarget) {
        this.messageTarget.style.opacity = 0.5
        setTimeout(() => {
          index++
          this.messageTarget.textContent = this.messages[index % this.messages.length]
          this.messageTarget.style.opacity = 1
        }, 200)
      }
    }, 2500)
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
    }

    document.querySelectorAll('button[disabled]').forEach(btn => {
      btn.disabled = false
      btn.classList.remove('opacity-50', 'cursor-not-allowed')
    })
  }
}