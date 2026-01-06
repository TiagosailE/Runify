# Lembrete de treino - todo dia às 8h da manhã
every 1.day, at: '8:00 am' do
  runner "WorkoutReminderJob.perform_later"
end

# Lembrete de sincronização - todo dia às 19h
every 1.day, at: '7:00 pm' do
  runner "SyncReminderJob.perform_later"
end

# Resumo semanal - todo domingo às 18h
every :sunday, at: '6:00 pm' do
  runner "WeeklySummaryJob.perform_later"
end