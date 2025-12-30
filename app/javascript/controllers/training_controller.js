import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "workoutId"]
  
  connect() {
    this.currentWorkoutId = null
  }

  async completeWorkout(event) {
    const workoutId = event.currentTarget.dataset.workoutId
    this.currentWorkoutId = workoutId
    
    try {
      const response = await fetch(`/training/${workoutId}/complete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (response.ok) {
        this.showFeedbackModal()
      }
    } catch (error) {
      console.error('Error completing workout:', error)
    }
  }

  async submitFeedback(event) {
    const difficulty = event.currentTarget.dataset.difficulty
    
    try {
      await fetch(`/training/${this.currentWorkoutId}/feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ difficulty })
      })

      window.location.reload()
    } catch (error) {
      console.error('Error submitting feedback:', error)
    }
  }

  showFeedbackModal() {
    const modal = document.getElementById('feedback-modal')
    if (modal) {
      modal.classList.remove('hidden')
    }
  }

  closeFeedback() {
    const modal = document.getElementById('feedback-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
    window.location.reload()
  }

  get csrfToken() {
    return document.querySelector('[name="csrf-token"]')?.content
  }
}