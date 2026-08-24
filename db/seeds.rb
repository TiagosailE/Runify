week_start = Date.current.beginning_of_week(:monday)

seed_password = if Rails.env.production?
  ENV.fetch("SEED_USER_PASSWORD") { raise "SEED_USER_PASSWORD é obrigatório para rodar o seed em produção" }
else
  ENV.fetch("SEED_USER_PASSWORD", "password123")
end

puts 'Seeding demo data...'

users_data = [
  {
    email: 'demo@runify.app',
    username: 'Demo Runner',
    weight: 68,
    height: 175,
    birth_date: Date.new(1993, 4, 18),
    goal: 'Completar 10 km com consistência e baixar o pace médio.',
    available_days: [ 2, 4, 6, 7 ],
    running_experience: 'intermediate',
    running_experience_years: 3,
    best_5k_time: 27 * 60,
    best_10k_time: 58 * 60,
    best_half_marathon_time: 128 * 60,
    weekly_mileage: 32,
    injury_history: 'Sem lesões recentes.',
    preferred_training_days: [ 2, 4, 6, 7 ],
    notifications_enabled: true
  },
  {
    email: 'pacer1@runify.app',
    username: 'Ana Pace',
    weight: 60,
    height: 168,
    birth_date: Date.new(1995, 9, 10),
    goal: 'Manter consistência e evoluir nos longões.',
    available_days: [ 2, 4, 6 ],
    running_experience: 'advanced',
    running_experience_years: 6,
    weekly_mileage: 45,
    injury_history: 'Sem histórico relevante.',
    preferred_training_days: [ 2, 4, 6 ],
    notifications_enabled: true
  },
  {
    email: 'pacer2@runify.app',
    username: 'Bruno Sprint',
    weight: 74,
    height: 180,
    birth_date: Date.new(1990, 1, 22),
    goal: 'Ganhar velocidade para provas curtas.',
    available_days: [ 3, 5, 7 ],
    running_experience: 'intermediate',
    running_experience_years: 4,
    weekly_mileage: 28,
    injury_history: 'Tensão leve na panturrilha no ano passado.',
    preferred_training_days: [ 3, 5, 7 ],
    notifications_enabled: false
  }
]

users = {}

users_data.each do |attributes|
  user = User.find_or_initialize_by(email: attributes[:email])
  user.assign_attributes(attributes.except(:email))
  if user.new_record?
    user.password = seed_password
    user.password_confirmation = seed_password
    user.terms_accepted = true
  end
  user.save!
  users[attributes[:email]] = user
end

demo_user = users.fetch('demo@runify.app')

training_plan = demo_user.training_plans.find_or_initialize_by(goal: 'Plano demo Runify')
training_plan.assign_attributes(
  goal: 'Plano demo Runify',
  status: 'active',
  start_date: week_start,
  end_date: week_start + 27.days,
  total_weeks: 4,
  plan_data: {
    'seed_key' => 'runify-demo-plan',
    'analysis' => 'Plano de demonstração para ambiente local.',
    'plan_duration_weeks' => 4,
    'weekly_volume_km' => 32
  }
)
training_plan.save!

workouts_data = [
  {
    week_number: 1,
    day_of_week: 2,
    scheduled_date: week_start + 1.day,
    workout_type: 'Corrida Leve',
    distance: 6.0,
    duration: 35.minutes,
    pace: '6:00-6:20/km',
    description: 'Rodagem leve para acumular volume com conforto.',
    instructions: 'Aqueça por 5 minutos e mantenha respiração controlada.',
    status: 'completed'
  },
  {
    week_number: 1,
    day_of_week: 4,
    scheduled_date: week_start + 3.days,
    workout_type: 'Intervalado',
    distance: 7.5,
    duration: 40.minutes,
    pace: '4:55-5:10/km',
    description: 'Treino de velocidade com blocos curtos.',
    instructions: 'Faça aquecimento de 10 minutos, 6 tiros de 400m e trote entre repetições.',
    status: 'pending'
  },
  {
    week_number: 1,
    day_of_week: 6,
    scheduled_date: week_start + 5.days,
    workout_type: 'Tempo Run',
    distance: 8.0,
    duration: 45.minutes,
    pace: '5:20-5:35/km',
    description: 'Bloco contínuo em ritmo sustentado.',
    instructions: 'Comece leve por 10 minutos e faça 20 minutos em ritmo forte controlado.',
    status: 'pending'
  },
  {
    week_number: 1,
    day_of_week: 7,
    scheduled_date: week_start + 6.days,
    workout_type: 'Longão',
    distance: 12.0,
    duration: 75.minutes,
    pace: '6:05-6:25/km',
    description: 'Corrida longa para desenvolver resistência.',
    instructions: 'Mantenha constância no pace e hidratação ao longo do treino.',
    status: 'pending'
  }
]

workouts_data.each do |attributes|
  workout = training_plan.workouts.find_or_initialize_by(
    week_number: attributes[:week_number],
    day_of_week: attributes[:day_of_week]
  )

  workout.assign_attributes(
    scheduled_date: attributes[:scheduled_date],
    workout_type: attributes[:workout_type],
    distance: attributes[:distance],
    duration: attributes[:duration],
    pace: attributes[:pace],
    description: attributes[:description],
    instructions: attributes[:instructions],
    status: attributes[:status],
    workout_details: {
      'seed_key' => "workout-#{attributes[:week_number]}-#{attributes[:day_of_week]}",
      'source' => 'db/seeds'
    }
  )

  workout.save!
end

squad = demo_user.owned_squads.find_or_initialize_by(name: 'Pacer Demo Runify')
squad.assign_attributes(
  description: 'Grupo demo com ranking e progresso para desenvolvimento local.',
  challenge_duration: 30,
  challenge_start: week_start,
  challenge_end: week_start + 29.days
)
squad.save!

[
  { user: demo_user, level: 8, experience_points: 80, streak: 5 },
  { user: users.fetch('pacer1@runify.app'), level: 12, experience_points: 40, streak: 9 },
  { user: users.fetch('pacer2@runify.app'), level: 5, experience_points: 30, streak: 3 }
].each do |attributes|
  squad_member = squad.squad_members.find_or_initialize_by(user: attributes[:user])
  squad_member.assign_attributes(
    level: attributes[:level],
    experience_points: attributes[:experience_points],
    streak: attributes[:streak],
    joined_at: week_start
  )
  squad_member.save!
end

notifications_data = [
  {
    title: 'Treino de Hoje!',
    message: 'Seu treino de Intervalado está pronto para ser concluído no app.',
    notification_type: 'workout_reminder',
    sent_at: Time.current
  },
  {
    title: 'Resumo Semanal',
    message: 'Você completou 1 de 4 treinos da semana. Continue consistente para ganhar mais XP.',
    notification_type: 'weekly_summary',
    sent_at: Time.current
  },
  {
    title: 'Parabéns!',
    message: 'Você concluiu sua corrida leve e manteve a sequência da semana.',
    notification_type: 'congratulations',
    sent_at: Time.current
  }
]

notifications_data.each do |attributes|
  notification = demo_user.notifications.find_or_initialize_by(
    title: attributes[:title],
    notification_type: attributes[:notification_type]
  )
  notification.assign_attributes(
    message: attributes[:message],
    sent_at: attributes[:sent_at],
    read: false
  )
  notification.save!
end

if Rails.env.production?
  puts "Demo user: #{demo_user.email} (senha definida via SEED_USER_PASSWORD)"
else
  puts "Demo user: #{demo_user.email} / #{seed_password}"
end
puts 'Demo data seeded successfully.'
