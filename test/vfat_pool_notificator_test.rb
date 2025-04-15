require 'minitest/autorun'
require '/workspaces/ruby-4/vfat_pool_notificator/src/vfat_pool_notificator.rb'

class VfatPoolNotificatorTest < Minitest::Test
  def test_email
    VfatPoolNotificator.new.send_email_with_sendgrid(-10, 0, 10, true)
  end
end