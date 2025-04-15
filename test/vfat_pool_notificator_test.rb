require 'minitest/autorun'
require '/workspaces/ruby-4/vfat_pool_notificator/src/vfat_pool_notificator.rb'

class VfatPoolNotificatorTest < Minitest::Test
  def test_email_with_sendgrid
    VfatPoolNotificator.new.send_email_using_sendgrid(-10, 0, 10, true)
  end

  def test_email_with_maileroo
    VfatPoolNotificator.new.send_email_using_maileroo(-10, 0, 20, true)
  end
end