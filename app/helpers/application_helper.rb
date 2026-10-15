module ApplicationHelper
  def day_name_pt(date)
    days = {
      "Sunday" => "Dom",
      "Monday" => "Seg",
      "Tuesday" => "Ter",
      "Wednesday" => "Qua",
      "Thursday" => "Qui",
      "Friday" => "Sex",
      "Saturday" => "Sáb"
    }
    days[date.strftime("%A")]
  end

  FLASH_TOAST_TYPES = { "notice" => "success", "alert" => "error" }.freeze

  # Todo retorno de acao vira toast: flash[:toast] dos controllers do app e
  # notice/alert do Devise, do rate_limit e dos redirects com alert:.
  def flash_toasts
    toasts = FLASH_TOAST_TYPES.filter_map do |key, type|
      { message: flash[key], type: type } if flash[key].present?
    end

    toast = flash[:toast]
    if toast.present?
      toast = toast.with_indifferent_access
      toasts << { message: toast[:message], type: toast[:type].presence || "info" } if toast[:message].present?
    end

    toasts
  end

  # Padrao de erro de formulario do app: mensagem embaixo do campo e borda
  # vermelha. Resultado de acao (salvou, falhou, sem conexao) vai em toast.
  def field_error(record, attribute)
    message = record&.errors&.full_messages_for(attribute)&.first
    return if message.blank?

    tag.p(message, class: "mt-2 text-sm text-red-600 dark:text-red-400", data: { field_error: attribute })
  end

  def field_border(record, attribute)
    record&.errors&.include?(attribute) ? "border-red-500" : "border-gray-300"
  end
end
