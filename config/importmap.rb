# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

pin "deferred_loader", to: "deferred_loader.js", preload: true
pin "prevent_deferred_loader", to: "prevent_deferred_loader.js", preload: true
pin "fundamentals_tooltip", to: "fundamentals_tooltip.js", preload: true
pin "sortable_table", to: "sortable_table.js", preload: true
pin "dashboard_list", to: "dashboard_list.js", preload: true
pin "hide_on_click", to: "hide_on_click.js", preload: true
# pin "line_chart", to: "line_chart.js", preload: true
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js" 
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js"
pin "jquery-ui", to: "https://code.jquery.com/ui/1.12.1/jquery-ui.min.js"
pin "jquery-ujs", to: "https://cdnjs.cloudflare.com/ajax/libs/jquery-ujs/1.2.3/rails.min.js"
pin "@jquery", to: "https://code.jquery.com/jquery-3.7.0.min.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"
