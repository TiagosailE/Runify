module ApplicationHelper
  def day_name_pt(date)
    days = {
      'Sunday' => 'Dom',
      'Monday' => 'Seg',
      'Tuesday' => 'Ter',
      'Wednesday' => 'Qua',
      'Thursday' => 'Qui',
      'Friday' => 'Sex',
      'Saturday' => 'Sáb'
    }
    days[date.strftime('%A')]
  end
end