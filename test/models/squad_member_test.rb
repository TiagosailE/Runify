require "test_helper"

class SquadMemberTest < ActiveSupport::TestCase
  def build_user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com", password: "password1234",
      username: name, terms_accepted: true
    )
  end

  def build_squad(owner)
    Squad.create!(name: "Pacer #{SecureRandom.hex(2)}", owner: owner, challenge_duration: 30,
                  challenge_start: Date.current, challenge_end: Date.current + 30.days)
  end

  def join(squad, user, level:, xp:)
    squad.squad_members.create!(user: user, level: level, experience_points: xp, streak: 0, joined_at: Time.current)
  end

  test "add_xp sobe varios niveis de uma vez e guarda o resto do XP" do
    user = build_user("corredor")
    member = join(build_squad(user), user, level: 1, xp: 0)

    member.add_xp(500) # nivel 1 pede 150 e o 2 pede 250: sobram 100 no nivel 3

    member.reload
    assert_equal 3, member.level
    assert_equal 100, member.experience_points
  end

  # Duas instancias da mesma linha, cada uma em memoria com o XP de antes:
  # sem recarregar dentro do lock, a segunda chamada soma sobre o valor
  # antigo e o XP da primeira some.
  test "add_xp recarrega o registro antes de somar, nao perde XP concorrente" do
    user = build_user("corredor")
    member = join(build_squad(user), user, level: 1, xp: 0)

    stale_a = SquadMember.find(member.id)
    stale_b = SquadMember.find(member.id)

    stale_a.add_xp(50)
    stale_b.add_xp(30)

    assert_equal 80, member.reload.experience_points
  end

  # User#level e User#experience_points leem do "principal": o de maior nivel,
  # nao o de maior XP (que zera a cada level-up).
  test "o pacer principal do usuario e o de maior nivel, nao o de maior XP" do
    user = build_user("corredor")
    low_level_lots_of_xp = join(build_squad(user), user, level: 1, xp: 140)
    high_level_little_xp = join(build_squad(user), user, level: 10, xp: 5)

    assert_equal high_level_little_xp, user.primary_squad_member
    assert_equal 10, user.level
    assert_equal 5, user.experience_points
    assert_not_equal low_level_lots_of_xp, user.primary_squad_member
  end

  test "com o mesmo nivel o principal e o de maior XP" do
    user = build_user("corredor")
    join(build_squad(user), user, level: 4, xp: 10)
    richer = join(build_squad(user), user, level: 4, xp: 90)

    assert_equal richer, user.primary_squad_member
  end
end
