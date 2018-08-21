# validate IPv4
require 'ipaddress'

class Node
  include ActiveModel::Model
  attr_accessor :device, :node_name, :wifi_channel, :bmx6_tun4, :vars
  validates :device, :node_name, :wifi_channel, :bmx6_tun4, presence: true

  # src https://medium.com/@rfleury2/a-quick-guide-to-model-errors-in-rails-965e2be3ac93
  validates_numericality_of :wifi_channel
  validate :validate_ip_address

  private

  # custom validation -> https://hackernoon.com/performing-custom-validations-in-rails-an-example-9a373e807144
  def validate_ip_address
    addr = bmx6_tun4
    ip, netmask = addr.split("/")

    unless IPAddress.valid_ipv4?(ip) && (!(netmask =~ /\A([12]?\d|3[0-2])\z/).nil? || IPAddress.valid_ipv4_netmask?(netmask))
    # TODO Need newer version of gem -> src https://github.com/ipaddress-gem/ipaddress/blob/master/lib/ipaddress.rb#L157-L161
    #unless IPAddress.valid_ipv4_subnet? addr
      errors.add(:bmx6_tun4, 'IP address invalid. Example: 10.0.0.1/27')
    end
  end
end
