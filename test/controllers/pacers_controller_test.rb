require "test_helper"

class PacersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get pacers_url
    assert_response :success
  end

  test "should get new" do
    get new_pacer_url
    assert_response :success
  end

  test "should get create" do
    post pacers_url, params: {
      squad: {
        name: "New Squad",
        description: "Test squad",
        challenge_duration: 7,
        challenge_start: Date.today,
        challenge_end: Date.today + 7.days
      }
    }
    assert_response :redirect
  end

  test "should get show" do
    get pacer_url(squads(:one))
    assert_response :success
  end

  test "nao membro recebe 404 ao ver o show" do
    get pacer_url(squads(:two))
    assert_response :not_found
  end

  test "ranking desenha a moldura do tier de cada membro" do
    squad_members(:one).update_columns(level: 45)

    get pacer_url(squads(:one))

    assert_select ".pacer-avatar.tier-golden_marathon img.pacer-avatar-frame[src*='pacer_frames/golden_marathon']"
  end

  test "todo tier tem imagem de moldura" do
    SquadMember::TIER_DATA.each_key do |tier|
      assert Rails.application.assets.load_path.find("pacer_frames/#{tier}.webp"), "falta pacer_frames/#{tier}.webp"
    end
  end

  test "join_by_code entra no squad com o codigo certo" do
    post join_by_code_pacers_url, params: { code: squads(:two).squad_code }

    assert_redirected_to pacer_path(squads(:two))
    assert squads(:two).users.include?(users(:one))

    follow_redirect!
    assert_response :success
  end

  test "join_by_code aceita codigo em minusculas e com espacos nas pontas" do
    post join_by_code_pacers_url, params: { code: "  #{squads(:two).squad_code.downcase} " }

    assert_redirected_to pacer_path(squads(:two))
    assert squads(:two).users.include?(users(:one))
  end

  test "join_by_code rejeita codigo invalido" do
    post join_by_code_pacers_url, params: { code: "codigo-que-nao-existe" }

    assert_redirected_to pacers_path
    assert_equal "Código inválido", flash[:alert]
  end

  test "should get leave" do
    sign_out users(:one)
    sign_in users(:two)

    delete leave_pacer_url(squads(:two))
    assert_response :redirect
  end

  test "nao membro recebe 404 ao tentar sair" do
    delete leave_pacer_url(squads(:two))
    assert_response :not_found
  end
end
