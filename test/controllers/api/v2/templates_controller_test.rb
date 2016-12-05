require 'test_helper'

class Api::V2::TemplatesControllerTest < ActionController::TestCase

  test "should import" do
    post :import, { 'repo':'https://github.com/theforeman/community-templates' }
    assert_response :success
  end

end
