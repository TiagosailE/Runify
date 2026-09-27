require "test_helper"

class XpServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def setup
    @user = User.create!(
      email: "xp-#{SecureRandom.hex(4)}@example.com",
      password: "password1234",
      username: "Teste",
      running_experience: "intermediate",
      weekly_mileage: 30,
      preferred_training_days: [ 1, 3, 5 ],
      terms_accepted: true
    )

    @squad = Squad.create!(
      name: "Squad Teste",
      description: "descricao",
      owner: @user,
      challenge_duration: 4,
      challenge_start: Date.current,
      challenge_end: nil
    )

    @squad_member = @squad.squad_members.create!(user: @user, joined_at: Time.current)
  end

  def create_activity(start_date)
    @user.activities.create!(
      name: "Corrida",
      sport_type: "Run",
      distance: 5000,
      duration: 1800,
      moving_time: 1800,
      average_speed: 2.78,
      start_date: start_date,
      source: "manual"
    )
  end

  test "calculate_xp soma km vezes dez, bonus de ritmo e bonus de streak" do
    @squad_member.update!(streak: 3)
    activity = create_activity(Time.current)
    activity.update!(distance: 5000, duration: 1500, moving_time: 1500)

    xp = XpService.calculate_xp(activity, @squad_member.reload)

    assert_equal 85, xp # 50 (5km x 10) + 5 (ritmo de 5:00/km) + 30 (streak 3 x 10)
  end

  test "ritmo mais lento que 6:00/km nao gera bonus negativo" do
    activity = create_activity(Time.current)
    activity.update!(distance: 5000, duration: 2100, moving_time: 2100)

    xp = XpService.calculate_xp(activity, @squad_member)

    assert_equal 50, xp # so a base: ritmo de 7:00/km fica no piso zero, sem streak
  end

  test "bonus de ritmo tem teto de 25" do
    activity = create_activity(Time.current)
    activity.update!(distance: 5000, duration: 60, moving_time: 60)

    xp = XpService.calculate_xp(activity, @squad_member)

    assert_equal 75, xp # 50 de base + teto de 25, ritmo bem abaixo de 6:00/km
  end

  test "award_xp da xp so em squads ativos" do
    ended_squad = Squad.create!(
      name: "Squad Encerrado", description: "descricao", owner: @user,
      challenge_duration: 4, challenge_start: 8.weeks.ago, challenge_end: 1.week.ago
    )
    ended_member = ended_squad.squad_members.create!(user: @user, joined_at: Time.current)
    activity = create_activity(Time.current)
    activity.update!(distance: 5000, duration: 1500, moving_time: 1500)

    XpService.award_xp(@user, activity)

    assert_equal 55, @squad_member.reload.experience_points # 50 de base + 5 de ritmo, sem streak
    assert_equal 0, ended_member.reload.experience_points
  end

  test "duas corridas no mesmo dia nao somam duas ao streak" do
    travel_to Time.zone.local(2026, 9, 27, 10, 0) do
      create_activity(Time.current)
      create_activity(Time.current + 1.hour)

      XpService.update_streak(@user)

      assert_equal 1, @squad_member.reload.streak
    end
  end

  test "dia pulado zera o streak" do
    travel_to Time.zone.local(2026, 9, 27, 10, 0) do
      create_activity(3.days.ago)

      XpService.update_streak(@user)

      assert_equal 0, @squad_member.reload.streak
    end
  end

  test "sete dias seguidos dao a conquista Semana Perfeita" do
    travel_to Time.zone.local(2026, 9, 27, 10, 0) do
      6.downto(0) { |n| create_activity(n.days.ago) }

      XpService.update_streak(@user)
      XpService.check_achievements(@user, @squad_member.reload)

      assert @user.achievements.exists?(name: "Semana Perfeita")
    end
  end

  test "streak termina ontem tambem conta, mas nao dois dias atras" do
    travel_to Time.zone.local(2026, 9, 27, 10, 0) do
      create_activity(1.day.ago)
      create_activity(2.days.ago)

      XpService.update_streak(@user)

      assert_equal 2, @squad_member.reload.streak
    end
  end

  test "pular do nivel 9 para o 11 ainda concede a conquista Nivel 10" do
    @squad_member.update!(level: 9, experience_points: 0)
    @squad_member.add_xp(2000)

    assert_equal 11, @squad_member.level

    XpService.check_achievements(@user, @squad_member)

    assert @user.achievements.exists?(name: "Nível 10")
  end
end
