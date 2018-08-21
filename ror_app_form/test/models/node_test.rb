require 'test_helper'

class NodeTest < ActiveSupport::TestCase
  test 'respond to attributes' do
    node = Node.new

    assert node.respond_to?(:node_name), 'does not respond to :node_name'
    assert node.respond_to?(:wifi_channel), 'does not respond to :node_name'
    assert node.respond_to?(:bmx6_tun4), 'does not respond to :bmx6_tun4'
  end

  test 'should be valid when all attributes are set' do
    attrs = { 
        node_name: 'BCNStreet13',
        wifi_channel: '132',
        bmx6_tun4: '10.1.1.1/27'
    }
    node = Node.new attrs
    assert node.valid?, 'should be valid'
  end

  test 'check attributes that are important' do
    node = Node.new

    refute node.valid?, 'Blank Mesage should be invalid'

    assert_match /blank/, node.errors[:node_name].to_s
    assert_match /blank/, node.errors[:wifi_channel].to_s
    assert_match /blank/, node.errors[:bmx6_tun4].to_s
  end
end
