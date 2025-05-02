require 'dotenv'
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
  SLEEP_DURATION = ENV['SLEEP_DURATION_SECONDS'].to_i
  CHAIN_HTTPS_URI = ENV['BASE_HTTPS_URI']

  MAILERSEND_API_KEY = ENV['MAILERSEND_API_KEY']
  MAILERSEND_EMAIL_FROM = ENV['MAILERSEND_EMAIL_FROM']
  MAILERSEND_EMAIL_TO = ENV['MAILERSEND_EMAIL_TO']

  CLPOOLS = ENV['CLPOOLS'].split(',')
  NFT_POSITION_MANAGER_ADDRESSES = ENV['NFT_POSITION_MANAGER_ADDRESSES'].split(',')
  CLPOOL_ADDRESSES = ENV['CLPOOL_ADDRESSES'].split(',')
  NFT_TOKEN_IDS = ENV['NFT_TOKEN_IDS'].split(',')

  def initialize
    @logger = Logger.new("/workspaces/ruby-4/vfat_pool_notificator/out/vfat_notificator.log")
    @logger.level = Logger::INFO
  end

  def run
    position_states = []
    CLPOOLS.each { |cp| position_states << PositionState::NONE }

    nft_position_manager_abi = File.read('/workspaces/ruby-4/vfat_pool_notificator/abi/nft_position_manager_abi.json')
    pool_abi = File.read('/workspaces/ruby-4/vfat_pool_notificator/abi/pool_abi.json')

    chain_client = Eth::Client.create(CHAIN_HTTPS_URI) 

    while true
      CLPOOLS.each_with_index do |clpool, idx|
        nft_position_manager_contract = Eth::Contract.from_abi(
          name: 'NonfungiblePositionManager', 
          address: NFT_POSITION_MANAGER_ADDRESSES[idx], 
          abi: nft_position_manager_abi
        )
  
        clpool_contract = Eth::Contract.from_abi(
            name: 'CLPool', 
            address: CLPOOL_ADDRESSES[idx], 
            abi: pool_abi
        )

        # Example: 49135
        current_price_tick = chain_client.call(clpool_contract, 'slot0')[1]

        # Example: 49100, 49200
        lower_price_tick, higher_price_tick = chain_client.call(
           nft_position_manager_contract, 
           'positions', 
            NFT_TOKEN_IDS[idx].to_i
         )[5..6]
   
         if position_states[idx] == PositionState::OUT_OF_RANGE && (current_price_tick < lower_price_tick || current_price_tick > higher_price_tick)
           @logger.info "#{clpool}: the current price #{current_price_tick} is out of range [#{lower_price_tick}, #{higher_price_tick}]. However, we've already sent email before. Skipping sending email."
         elsif position_states[idx] != PositionState::OUT_OF_RANGE && (current_price_tick < lower_price_tick || current_price_tick > higher_price_tick)
           @logger.info "#{clpool}: the current price #{current_price_tick} is out of range [#{lower_price_tick}, #{higher_price_tick}]. Sending email."
           
           position_states[idx] = PositionState::OUT_OF_RANGE
   
           send_email_using_mailersend(clpool, current_price_tick, lower_price_tick, higher_price_tick, false)
         else
           @logger.info "#{clpool}: the current price is in range: #{lower_price_tick} < #{current_price_tick} < #{higher_price_tick}. Skipping sending email."
   
           position_states[idx] = PositionState::IN_RANGE
         end
      end

      @logger.info "Going to sleep for #{SLEEP_DURATION} seconds."
      sleep SLEEP_DURATION
    end
  rescue => e
    @logger.error "Stopping. There was error in VfatPoolNotificator execution: #{e.message}"
  end

  def send_email_using_mailersend(pool, current, min, max, test)
    ms_client = Mailersend::Client.new(MAILERSEND_API_KEY)
    ms_email = Mailersend::Email.new(ms_client)

    ms_email.add_recipients("email" => MAILERSEND_EMAIL_TO)
    ms_email.add_from("email" => MAILERSEND_EMAIL_FROM)
    ms_email.add_subject(test ? '[TEST] Position out of range' : 'Position out of range')
    ms_email.add_text("The #{pool} position #{current} is out of range [#{min}, #{max}]. #{Time.now.in_time_zone("Pacific Time (US & Canada)")}. Don't forget to rebalance, update notificator config with new NFT ID, and restart the notificator.")

    response = ms_email.send

    @logger.info test ? "[TEST] Email sent using Mailersend! Code: #{response.code}." : "Email sent using Mailersend! Code: #{response.code}."
  rescue => e
    @logger.error test ? "[TEST] Error sending email using Mailersend: #{e.message}" : "Error sending email using Mailersend: #{e.message}"
  end
end
