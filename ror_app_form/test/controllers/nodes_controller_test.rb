require 'test_helper'

class NodesControllerTest < ActionDispatch::IntegrationTest
  test "GET new" do
    get new_node_url

    assert_response :success

    assert_select 'form' do
      assert_select 'input[type=text]'
      assert_select 'input[type=text]'
      assert_select 'input[type=text]'
      assert_select 'input[type=submit]'
    end
  end

  test "POST create" do
    post create_node_url, params: {
      node: {
        node_name: 'BCNStreet13',
        wifi_channel: '132',
        bmx6_tun4: '10.1.1.1/27'
      }
    }

    assert_redirected_to new_node_url

    follow_redirect!

    assert_match /Message received, thanks!/, response.body
  end

  test "invalid POST create" do
    post create_node_url, params: {
      node: { node_name: '', wifi_channel: '', bmx6_tun4: '' }
    }

    assert_match /Node name .* blank/, response.body
    assert_match /Wifi channel .* blank/, response.body
    assert_match /Bmx6 tun4 .* blank/, response.body
  end
end
