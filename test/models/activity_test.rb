require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  def valid_attributes
    {
      user: users(:one),
      name: "Corrida",
      sport_type: "Run",
      distance: 5000,
      duration: 1500,
      moving_time: 1500,
      start_date: Time.current,
      source: "manual"
    }
  end

  test "valid with distance, duration, start_date and sport_type" do
    activity = Activity.new(valid_attributes)
    assert activity.valid?
  end

  test "invalid without a positive distance" do
    activity = Activity.new(valid_attributes.merge(distance: 0))
    assert_not activity.valid?
    assert_includes activity.errors[:distance], "deve ser maior que zero"
  end

  test "invalid without a positive duration" do
    activity = Activity.new(valid_attributes.merge(duration: nil))
    assert_not activity.valid?
    assert_includes activity.errors[:duration], "deve ser maior que zero"
  end

  test "invalid without start_date" do
    activity = Activity.new(valid_attributes.merge(start_date: nil))
    assert_not activity.valid?
  end

  test "invalid without sport_type" do
    activity = Activity.new(valid_attributes.merge(sport_type: nil))
    assert_not activity.valid?
  end

  test "invalid with a source outside the known list" do
    activity = Activity.new(valid_attributes.merge(source: "made_up"))
    assert_not activity.valid?
  end

  test "distance_km converts meters to kilometers" do
    activity = Activity.new(valid_attributes.merge(distance: 5432))
    assert_equal 5.43, activity.distance_km
  end

  test "pace_per_km formats minutes and seconds" do
    activity = Activity.new(valid_attributes.merge(distance: 5000, moving_time: 1500))
    assert_equal "5:00'", activity.pace_per_km
  end

  test "run? reconhece Run, TrailRun e VirtualRun, mas nao outros esportes" do
    assert Activity.new(valid_attributes.merge(sport_type: "Run")).run?
    assert Activity.new(valid_attributes.merge(sport_type: "TrailRun")).run?
    assert Activity.new(valid_attributes.merge(sport_type: "VirtualRun")).run?
    assert_not Activity.new(valid_attributes.merge(sport_type: "Ride")).run?
    assert_not Activity.new(valid_attributes.merge(sport_type: "Swim")).run?
    assert_not Activity.new(valid_attributes.merge(sport_type: "Walk")).run?
  end

  test "scope runs traz so as atividades de corrida" do
    user = users(:one)
    corrida = user.activities.create!(valid_attributes.except(:user).merge(sport_type: "Run"))
    pedal = user.activities.create!(valid_attributes.except(:user).merge(sport_type: "Ride"))

    assert_includes user.activities.runs, corrida
    assert_not_includes user.activities.runs, pedal
  end
end
