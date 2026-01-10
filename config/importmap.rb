pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "toast", to: "toast.js", preload: true
pin "theme", to: "theme.js"
pin "settings", to: "settings.js"
pin "charts", to: "charts.js"
pin "training", to: "training.js"
pin "profile", to: "profile.js"