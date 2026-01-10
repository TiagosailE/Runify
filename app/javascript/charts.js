document.addEventListener('turbo:load', () => {
  const isDark = document.documentElement.classList.contains('dark');
  document.querySelectorAll('.chart-month-label').forEach(l => l.setAttribute('fill', isDark ? '#d1d5db' : '#666'));
  document.querySelectorAll('.chart-value-label').forEach(l => l.setAttribute('fill', isDark ? '#f3f4f6' : '#333'));
});