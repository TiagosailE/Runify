require "test_helper"

class SquadTest < ActiveSupport::TestCase
  def build_user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com", password: "password123",
      username: name, terms_accepted: true
    )
  end

  def build_squad(owner)
    Squad.create!(name: "Pacer de teste", owner: owner, challenge_duration: 30,
                  challenge_start: Date.current, challenge_end: Date.current + 30.days)
  end

  def join(squad, user, level:, xp:)
    squad.squad_members.create!(user: user, level: level, experience_points: xp, streak: 0, joined_at: Time.current)
  end

  # O XP zera a cada level-up, entao ordenar por XP antes do nivel colocava
  # quem acabou de subir de nivel abaixo de quem tem nivel menor.
  test "leaderboard ordena por nivel antes do XP" do
    owner = build_user("dono")
    squad = build_squad(owner)
    veteran_fresh_level = join(squad, owner, level: 10, xp: 5)
    newcomer_lots_of_xp = join(squad, build_user("novato"), level: 1, xp: 140)
    veteran_more_xp = join(squad, build_user("veterano"), level: 10, xp: 50)

    assert_equal [ veteran_more_xp, veteran_fresh_level, newcomer_lots_of_xp ], squad.leaderboard.to_a
  end

  test "level-up que atravessa varios niveis de uma vez reordena o ranking" do
    owner = build_user("dono")
    squad = build_squad(owner)
    steady = join(squad, owner, level: 2, xp: 200)
    climber = join(squad, build_user("escalador"), level: 1, xp: 0)

    assert_equal [ steady, climber ], squad.leaderboard.to_a

    climber.add_xp(500) # 150 para o nivel 2, 250 para o 3: sobe dois niveis de uma vez

    assert_equal 3, climber.reload.level
    assert_equal [ climber, steady ], squad.leaderboard.to_a
  end
end
