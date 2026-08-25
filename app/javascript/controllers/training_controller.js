import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "workoutId", "notes"]

  connect() {
    this.currentWorkoutId = null
    this.selectedDifficulty = null
  }

  async completeWorkout(event) {
    const button = event.currentTarget
    const workoutId = button.dataset.workoutId

    if (!confirm('Marcar este treino como concluído?')) {
      return
    }

    await this.performComplete(workoutId, button)
  }

  openCompleteModal(event) {
    const button = event.currentTarget
    this.currentWorkoutId = button.dataset.workoutId

    const modal = document.getElementById('complete-workout-modal')
    if (modal) {
      modal.classList.remove('hidden')
    }
  }

  cancelComplete() {
    const modal = document.getElementById('complete-workout-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  async confirmComplete() {
    const modal = document.getElementById('complete-workout-modal')
    if (modal) {
      modal.classList.add('hidden')
    }

    await this.performComplete(this.currentWorkoutId, document.getElementById('complete-workout-button'))
  }

  async performComplete(workoutId, button) {
    this.currentWorkoutId = workoutId

    if (button) {
      button.disabled = true
    }
    const originalContent = button?.innerHTML

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
        this.handleCompleteError(button, originalContent)
      }
    } catch (error) {
      console.error('Error completing workout:', error)
      this.handleCompleteError(button, originalContent)
    }
  }

  handleCompleteError(button, originalContent) {
    if (typeof window.showToast === 'function') {
      window.showToast('Erro ao completar treino', 'error')
    } else {
      alert('Erro ao completar treino')
    }
    if (button) {
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

  selectDifficulty(event) {
    const button = event.currentTarget
    this.selectedDifficulty = button.dataset.difficulty

    document.querySelectorAll('.difficulty-option').forEach((el) => {
      el.classList.remove('border-teal-500', 'bg-teal-50', 'dark:bg-teal-900/20')
    })
    button.classList.add('border-teal-500', 'bg-teal-50', 'dark:bg-teal-900/20')
  }

  async submitFeedback() {
    if (!this.selectedDifficulty) {
      if (typeof window.showToast === 'function') {
        window.showToast('Escolha uma opção de dificuldade', 'warning')
      } else {
        alert('Escolha uma opção de dificuldade')
      }
      return
    }

    const notes = this.hasNotesTarget ? this.notesTarget.value.trim() : ''

    try {
      const response = await fetch(`/training/${this.currentWorkoutId}/feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ difficulty: this.selectedDifficulty, notes })
      })

      const data = await response.json()

      if (response.ok && data.success && typeof window.showToast === 'function') {
        window.showToast('Feedback enviado! Obrigado!', 'success')
      }
    } catch (error) {
      console.error('Error submitting feedback:', error)
    } finally {
      this.closeFeedback()
      setTimeout(() => {
        window.location.reload()
      }, 800)
    }
  }

  skipFeedback() {
    this.closeFeedback()
    window.location.reload()
  }

  showFeedbackModal() {
    this.selectedDifficulty = null
    if (this.hasNotesTarget) {
      this.notesTarget.value = ''
    }
    document.querySelectorAll('.difficulty-option').forEach((el) => {
      el.classList.remove('border-teal-500', 'bg-teal-50', 'dark:bg-teal-900/20')
    })

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
