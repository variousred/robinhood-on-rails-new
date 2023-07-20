class PositionsAndQuotesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "positions_and_quotes_channel" + session_id
    Rails.cache.redis.sadd "active_position_and_quote_subscriptions", session_id
  end

  def unsubscribed
    Rails.cache.redis.srem "active_position_and_quote_subscriptions", session_id
  end

  def self.active_subscriptions
    Rails.cache.redis.smembers "active_position_and_quote_subscriptions"
  end
end