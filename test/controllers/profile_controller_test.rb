require "test_helper"

class ProfileControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get profile_url
    assert_response :success
  end

  test "should get update" do
    patch profile_update_url, params: { user: { username: "Updated User", weight: 70, height: 175, goal: "5k" } }
    assert_redirected_to profile_path
  end

  test "update rejeita avatar invalido e mantem o anterior intacto" do
    users(:one).avatar.attach(io: StringIO.new("original"), filename: "original.png", content_type: "image/png")
    original_blob_id = users(:one).avatar.blob.id

    [
      Rack::Test::UploadedFile.new(StringIO.new("texto"), "text/plain", original_filename: "arquivo.txt"),
      Rack::Test::UploadedFile.new(StringIO.new("<svg></svg>"), "image/svg+xml", original_filename: "arquivo.svg"),
      Rack::Test::UploadedFile.new(StringIO.new("a" * 6.megabytes), "image/png", original_filename: "grande.png")
    ].each do |arquivo_invalido|
      patch profile_update_url, params: { user: { username: "Nome Novo", avatar: arquivo_invalido } }

      assert_redirected_to profile_path
      assert_equal "error", flash[:toast][:type]
      users(:one).reload
      assert_equal original_blob_id, users(:one).avatar.blob.id
      assert_not_equal "Nome Novo", users(:one).username
    end
  end

  test "avatar valido so troca de verdade se o resto do perfil tambem for valido" do
    users(:one).avatar.attach(io: StringIO.new("original"), filename: "original.png", content_type: "image/png")
    original_blob_id = users(:one).avatar.blob.id

    novo_avatar = Rack::Test::UploadedFile.new(StringIO.new("novo"), "image/png", original_filename: "novo.png")

    patch profile_update_url, params: { user: { weight: 999, avatar: novo_avatar } }

    assert_redirected_to profile_path
    assert_equal "error", flash[:toast][:type]
    users(:one).reload
    assert_equal original_blob_id, users(:one).avatar.blob.id
  end
end
