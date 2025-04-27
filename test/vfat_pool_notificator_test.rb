require 'minitest/autorun'
require '/workspaces/ruby-4/vfat_pool_notificator/src/vfat_pool_notificator.rb'

class VfatPoolNotificatorTest < Minitest::Test
  def test_email_using_mailersend
    VfatPoolNotificator.new.send_email_using_mailersend('WETH/uSUI', -10, 0, 20, true)
  end
end