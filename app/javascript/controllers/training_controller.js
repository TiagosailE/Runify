import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "workoutId"]
  
  connect() {
    this.currentWorkoutId = null
  }

  async completeWorkout(event) {
    const button = event.currentTarget
    const workoutId = button.dataset.workoutId
    this.currentWorkoutId = workoutId

    if (!confirm('Marcar este treino como concluído?')) {
      return
    }

    button.disabled = true
    const originalContent = button.innerHTML
    button.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Processando...'
    
    try {
      const response = await fetch(`/training/${workoutId}/complete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      const data = await response.json()

      if (response.ok && data.success) {
        if (typeof window.showToast === 'function') {
          window.showToast('Treino concluído! Parabéns!', 'success')
        }
        this.showFeedbackModal()
      } else {
        if (typeof window.showToast === 'function') {
          window.showToast('Erro ao completar treino', 'error')
        } else {
          alert('Erro ao completar treino')
        }
        button.disabled = false
        button.innerHTML = originalContent
      }
    } catch (error) {
      console.error('Error completing workout:', error)
      if (typeof window.showToast === 'function') {
        window.showToast('Erro ao completar treino', 'error')
      } else {
        alert('Erro ao completar treino')
      }
      button.disabled = false
      button.innerHTML = originalContent
    }
  }

  toggleWorkout(event) {
    const button = event.currentTarget
    const workoutId = button.dataset.workoutId

    if (button.classList.contains('bg-teal-500')) {
      return
    }

    if (!button.classList.contains('animate-pulse')) {
      if (typeof window.showToast === 'function') {
        window.showToast('Este treino não está disponível hoje', 'warning')
      } else {
        alert('Este treino não está disponível hoje')
      }
      return
    }

    const simulatedEvent = {
      currentTarget: button,
      preventDefault: () => {}
    }
    
    this.completeWorkout(simulatedEvent)
  }

  async submitFeedback(event) {
    const difficulty = event.currentTarget.dataset.difficulty
    
    try {
      const response = await fetch(`/training/${this.currentWorkoutId}/feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ difficulty })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        this.closeFeedback()

        if (typeof window.showToast === 'function') {
          window.showToast('Feedback enviado! Obrigado!', 'success')
        }
        
        setTimeout(() => {
          window.location.reload()
        }, 800)
      }
    } catch (error) {
      console.error('Error submitting feedback:', error)
      this.closeFeedback()
      window.location.reload()
    }
  }

  showFeedbackModal() {
    const modal = document.getElementById('feedback-modal')
    if (modal) {
      modal.classList.remove('hidden')
      modal.classList.add('backdrop-blur-sm')
    }
  }

  closeFeedback() {
    const modal = document.getElementById('feedback-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  get csrfToken() {
    return document.querySelector('[name="csrf-token"]')?.content
  }
}