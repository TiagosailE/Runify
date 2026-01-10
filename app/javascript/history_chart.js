let chartObserver = null;

function updateChartColors() {
  const isDark = document.documentElement.classList.contains('dark');
  const monthLabels = document.querySelectorAll('.chart-month-label');
  const valueLabels = document.querySelectorAll('.chart-value-label');
  
  monthLabels.forEach(label => {
    label.setAttribute('fill', isDark ? '#d1d5db' : '#666');
  });
  
  valueLabels.forEach(label => {
    label.setAttribute('fill', isDark ? '#f3f4f6' : '#333');
  });
}

function initChartObserver() {
  if (chartObserver) {
    chartObserver.disconnect();
  }
  
  chartObserver = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.attributeName === 'class') {
        updateChartColors();
      }
    });
  });
  
  chartObserver.observe(document.documentElement, { attributes: true });
}

document.addEventListener('turbo:load', () => {
  const chartLabels = document.querySelectorAll('.chart-month-label, .chart-value-label');
  
  if (chartLabels.length > 0) {
    updateChartColors();
    initChartObserver();
  }
});

document.addEventListener('turbo:before-cache', () => {
  if (chartObserver) {
    chartObserver.disconnect();
    chartObserver = null;
  }
});