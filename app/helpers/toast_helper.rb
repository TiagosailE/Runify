module ToastHelper
  def show_toast(message, type = "info")
    flash[:toast] = { message: message, type: type }
    flash.keep(:toast)
  end

  def toast_success(message)
    show_toast(message, "success")
  end

  def toast_error(message)
    show_toast(message, "error")
  end

  def toast_warning(message)
    show_toast(message, "warning")
  end

  def toast_info(message)
    show_toast(message, "info")
  end

  def render_toast_script
    if flash[:toast].present?
      # Log para debug
      Rails.logger.info "Rendering toast: #{flash[:toast].inspect}"

      javascript_tag "window.showToast('#{j flash[:toast][:message]}', '#{flash[:toast][:type] || "info"}');"
    end
  end
end
