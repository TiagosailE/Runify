window.showCompleteWorkoutModal = function(workoutId) {
  const modal = document.getElementById('complete-workout-modal');
  if (modal) {
    modal.dataset.workoutId = workoutId;
    modal.classList.remove('hidden');
  }
};

window.hideCompleteWorkoutModal = function() {
  const modal = document.getElementById('complete-workout-modal');
  if (modal) {
    modal.classList.add('hidden');
    delete modal.dataset.workoutId;
  }
};

window.confirmCompleteWorkout = async function() {
  const modal = document.getElementById('complete-workout-modal');
  const workoutId = modal?.dataset.workoutId;
  
  if (!workoutId) {
    console.error('Workout ID não encontrado');
    return;
  }
  
  try {
    const response = await fetch(`/training/${workoutId}/complete`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      }
    });
    
    const data = await response.json();
    
    if (data.success) {
      window.hideCompleteWorkoutModal();
      
      if (typeof window.showToast === 'function') {
        window.showToast(data.message, 'success');
      }

      setTimeout(() => {
        window.location.reload();
      }, 1000);
    } else {
      window.hideCompleteWorkoutModal();
      
      if (typeof window.showToast === 'function') {
        window.showToast(data.message || 'Erro ao completar treino', 'error');
      }
    }
  } catch (error) {
    console.error('Erro ao completar treino:', error);
    window.hideCompleteWorkoutModal();
    
    if (typeof window.showToast === 'function') {
      window.showToast('Erro ao completar treino', 'error');
    }
  }
};

document.addEventListener('turbo:load', () => {
  const modal = document.getElementById('complete-workout-modal');
  
  if (modal) {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        window.hideCompleteWorkoutModal();
      }
    });
  }
});