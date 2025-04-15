require 'dotenv'
require 'sendgrid-ruby'
require 'eth'
require 'active_support'
require 'active_support/core_ext/time'
require 'httparty'
require 'byebug'
require "mailersend-ruby"

Dotenv.load('../.env')

class PositionState
  NONE = 'none'
  IN_RANGE = 'in_range'
  OUT_OF_RANGE = 'out_of_range'
end

class VfatPoolNotificator
  include SendGrid

  SLEEP_DURATION = ENV['SLEEP_DURATION_SECONDS'].to_i
  CHAIN_HTTPS_URI = ENV['BASE_HTTPS_URI']
  NFT_POSITION_MANAGER_ADDRESS = ENV['NFT_POSITION_MANAGER_ADDRESS']
  CLPOOL_ADDRESS = ENV['CLPOOL_ADDRESS']
  NFT_TOKEN_ID = ENV['NFT_TOKEN_ID']
  SENDGRID_EMAIL_FROM = ENV['SENDGRID_EMAIL_FROM']
  SENDGRID_EMAIL_TO = ENV['SENDGRID_EMAIL_TO']
  SENDGRID_API_KEY = ENV['SENDGRID_API_KEY']
  MAILEROO_API_KEY = ENV['MAILEROO_API_KEY']
  MAILEROO_EMAIL_FROM = ENV['MAILEROO_EMAIL_FROM']
  MAILEROO_EMAIL_TO = ENV['MAILEROO_EMAIL_TO']
  MAILEROO_API_KEY_HEADER = ENV['MAILEROO_API_KEY_HEADER']
  MAILEROO_REQUEST_URL = ENV['MAILEROO_REQUEST_URL']
  MAILERSEND_API_KEY = ENV['MAILERSEND_API_KEY']
  MAILERSEND_EMAIL_FROM = ENV['MAILERSEND_EMAIL_FROM']
  MAILERSEND_EMAIL_TO = ENV['MAILERSEND_EMAIL_TO']

  def initialize
    @logger = Logger.new("/workspaces/ruby-4/vfat_pool_notificator/out/vfat_notificator.log")
    @logger.level = Logger::INFO
  end

  def run
    position_state = PositionState::NONE

    nft_position_manager_abi = File.read('/workspaces/ruby-4/vfat_pool_notificator/abi/nft_position_manager_abi.json')
    pool_abi = File.read('/workspaces/ruby-4/vfat_pool_notificator/abi/pool_abi.json')

    chain_client = Eth::Client.create(CHAIN_HTTPS_URI) 

    nft_position_manager_contract = Eth::Contract.from_abi(
        name: 'NonfungiblePositionManager', 
        address: NFT_POSITION_MANAGER_ADDRESS, 
        abi: nft_position_manager_abi
    )

    clpool_contract = Eth::Contract.from_abi(
        name: 'CLPool', 
        address: CLPOOL_ADDRESS, 
        abi: pool_abi
    )

    while true
     # Example: 49135
     current_price_tick = chain_client.call(clpool_contract, 'slot0')[1]

     # Example: 49100, 49200
     lower_price_tick, higher_price_tick = chain_client.call(
        nft_position_manager_contract, 
        'positions', 
         NFT_TOKEN_ID.to_i
      )[5..6]

      if position_state == PositionState::OUT_OF_RANGE && (current_price_tick < lower_price_tick || current_price_tick > higher_price_tick)
        @logger.info "The current price #{current_price_tick} is out of range [#{lower_price_tick}, #{higher_price_tick}]. However, we've already sent email before. Skipping sending email and going to sleep for #{SLEEP_DURATION} seconds."
      elsif position_state != PositionState::OUT_OF_RANGE && (current_price_tick < lower_price_tick || current_price_tick > higher_price_tick)
        @logger.info "The current price #{current_price_tick} is out of range [#{lower_price_tick}, #{higher_price_tick}]. Sending email and going to sleep for #{SLEEP_DURATION} seconds."
        
        position_state = PositionState::OUT_OF_RANGE

        send_email_using_mailersend(current_price_tick, lower_price_tick, higher_price_tick, false)
      else
        @logger.info "The current price is in range: #{lower_price_tick} < #{current_price_tick} < #{higher_price_tick}. Skipping sending email and going to sleep for #{SLEEP_DURATION} seconds."

        position_state = PositionState::IN_RANGE
      end

      sleep SLEEP_DURATION
    end

  rescue => e
    @logger.error "Stopping. There was error in VfatPoolNotificator execution: #{e.message}"
  end

  def send_email_using_mailersend(current, min, max, test)
    ms_client = Mailersend::Client.new(MAILERSEND_API_KEY)
    ms_email = Mailersend::Email.new(ms_client)

    ms_email.add_recipients("email" => MAILERSEND_EMAIL_TO)
    ms_email.add_from("email" => MAILERSEND_EMAIL_FROM)
    ms_email.add_subject(test ? '[TEST] Position out of range' : 'Position out of range')
    ms_email.add_text("The CL - SUI/ETH position #{current} is out of range [#{min}, #{max}]. #{Time.now.in_time_zone("Pacific Time (US & Canada)")}. Don't forget to rebalance, update notificator config with new NFT ID, and restart the notificator.")

    response = ms_email.send

    @logger.info test ? "[TEST] Email sent using Mailersend! Code: #{response.code}." : "Email sent using Mailersend! Code: #{response.code}."
  rescue => e
    @logger.error test ? "[TEST] Error sending email using Mailersend: #{e.message}" : "Error sending email using Mailersend: #{e.message}"
  end

  def send_email_using_sendgrid(current, min, max, test)
    from = Email.new(email: SENDGRID_EMAIL_FROM)
    to = Email.new(email: SENDGRID_EMAIL_TO)
    subject = test ? '[TEST] Position out of range' : 'Position out of range'
    content = Content.new(type: 'text/plain', value: "The CL - SUI/ETH position #{current} is out of range [#{min}, #{max}]. #{Time.now.in_time_zone("Pacific Time (US & Canada)")}. Don't forget to rebalance, update notificator config with new NFT ID, and restart the notificator.")
    mail = Mail.new(from, subject, to, content)

    sg = SendGrid::API.new(api_key: SENDGRID_API_KEY)
    response = sg.client.mail._('send').post(request_body: mail.to_json)

    @logger.info test ? "[TEST] Email sent using Sendgrid! Code: #{response.status_code}." : "Email sent using Sendgrid! Code: #{response.status_code}."
  rescue => e
    @logger.error test ? "[TEST] Error sending email using Sendgrid: #{e.message}" : "Error sending email using Sendgrid: #{e.message}"
  end

  def send_email_using_maileroo(current, min, max, test)
    body = { 
      :from => MAILEROO_EMAIL_FROM, 
      :to => MAILEROO_EMAIL_TO, 
      :subject => test ? '[TEST] Position out of range' : 'Position out of range', 
      :plain => "The CL - SUI/ETH position #{current} is out of range [#{min}, #{max}]. #{Time.now.in_time_zone("Pacific Time (US & Canada)")}. Don't forget to rebalance, update notificator config with new NFT ID, and restart the notificator."
    }.to_json

    headers = {
        'Content-Type' => 'multipart/form-data',
        MAILEROO_API_KEY_HEADER => MAILEROO_API_KEY
    }

    response = HTTParty.post(MAILEROO_REQUEST_URL, :body => body, :headers => headers)

    if response.parsed_response['success']
      @logger.info test ? '[TEST] Email sent using Maileroo!' : 'Email sent using Maileroo!'
    else
      @logger.error test ? "[TEST] Error sending email using Maileroo: #{response.parsed_response['message']}" : "Error sending email using Maileroo: #{response.parsed_response['message']}"
    end
  rescue => e
    @logger.error test ? "[TEST] Error sending email using Maileroo: #{e.message}" : "Error sending email using Maileroo: #{e.message}"
  end
end
