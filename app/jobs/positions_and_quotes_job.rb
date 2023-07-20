class PositionsAndQuotesJob
  include Sidekiq::Job
  sidekiq_options retry: 0, backtrace: true

  include Robinhood

  def perform(session_id)
    puts "Performing PositionsAndQuotesJob for session_id and JID: #{session_id}, #{@jid}}"

    @session_id = session_id
    # Don't do anything if there are no active subscriptions
    # puts PositionsAndQuotesChannel.active_subscriptions
    # return unless PositionsAndQuotesChannel.active_subscriptions.any?
    # puts "Active subscriptions found"

    # Fetch positions and quotes

    # investments = {}
    # instruments = []
    puts "sidekiq job: about to get positions"
    get_positions
    @positions.each do |position|
      puts "\nposition: #{position}"
      puts "sidekiq job: about to call find_or_create_instrument for: #{position["instrument"]}"
      instrument = find_or_create_instrument position["instrument"]
      # instruments << instrument
      # position["instrument"] = instrument
      position["symbol"] = instrument.symbol
    end
    # options
    # @option_investments = {}
    get_aggregate_positions
    @aggregate_positions.each do |aggregate_position|
      puts "\nsidekiq: aggregate_position: #{aggregate_position}"
      puts "\nsidekiq job: about to call find_or_create_instrument for:"
      puts "\n#{aggregate_position["legs"][0]["option"]}"

      instrument = find_or_create_instrument(aggregate_position["legs"][0]["option"])
      # instruments << instrument
      # aggregate_position["instrument"] = instrument
      aggregate_position[["symbol"]] = instrument.symbol
    end
    # https://api.robinhood.com/options/aggregate_positions/?account_numbers=5SE30723&nonzero=True
    
    symbols = @positions.map { |position| position["symbol"] }  
    # do we even need to get quotes?  yes, for last trade price
    get_quotes(symbols)
    # @quotes.each do |quote|
      # quote.delete "instrument" # we already have it
      # investments[quote["symbol"]].merge! quote
    # end

    # Combine the positions and quotes into a single data structure
    # combined_data = @positions.zip(@quotes).map do |position, quote|
    #   { position: position, quote: quote }
    # end
    @positions = @positions.each do |position|
      matched_quote = @quotes.select {|quote| quote["instrument_id"] == position["instrument_id"]}[0]
      position.merge!(matched_quote)
    end
    puts "positions: #{@positions}"
    # Broadcast the combined data

    # ActionCable.server.broadcast "positions_and_quotes_channel#{session_id}", combined_data
    puts "Broadcasted positions and quotes"
    # puts combined_data
    broadcast_combined_data(session_id, @positions)
  end

  def session
    @session ||= begin
        public_session_id = @session_id
        private_session_id = Rack::Session::SessionId.new(public_session_id).private_id
        redis_key = "_session_id:" + private_session_id
        my_session = Rails.cache.read("_session_id:" + private_session_id)
        my_session.symbolize_keys
      end
  end

  def broadcast_combined_data(session_id, combined_data)
    # Render the partial with the provided data
    rendered_data = ApplicationController.renderer.render(
      partial: 'robinhood/positions_test',
      locals: { data: combined_data }
    )
  
    # Wrap the rendered data in a turbo-stream action
    stream_message = %(
      <turbo-stream action="replace" target="positions_test">
        <template>#{rendered_data}</template>
      </turbo-stream>
    )
  
    # Broadcast the data to the corresponding stream
    Rails.logger.info "Broadcasting to positions_and_quotes_channel#{session_id}"
    ActionCable.server.broadcast("positions_and_quotes_channel#{session_id}", { content: stream_message })
  end
end