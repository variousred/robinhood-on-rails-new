require 'pry'
module Robinhood
  extend ActiveSupport::Concern

  # endpoints
  ROBINHOOD_URL = "https://robinhood.com"
  ROBINHOOD_API_URL = "https://api.robinhood.com"
  ROBINHOOD_CRYPTO_URL = "https://nummus.robinhood.com"

  # colors
  ROBINHOOD_GREEN = "#21ce99"
  ROBINHOOD_ORANGE = "#fc4d2d"

  def get_login_variables
    response = `curl #{ROBINHOOD_URL}/login/`
    raw_vars = response.scan(/(window\.\w+\s*=\s*'?\S+'?;)+/).flatten
    raw_vars += response.scan(/(\w+:\s*"\S+")+/).flatten.map{|e| e.gsub(':', '=')}
    parsed_vars = {}
    raw_vars.each do |v|
      if v =~ /[window\.]?(\w+)\s*=\s*[\\\"|'](\S+)[\\\"|']/i
        parsed_vars[$1] = $2
      end
    end

    # It seems robinhood no longer puts info in window vars any more
    # Check generated JS scripts sent with HTML response for client ID
    # JS script we're looking for looks like:
    # https://cdn.robinhood.com/assets/generated_assets/App-1a08b7382e131f681667.js
    if response =~ /(https\S+App-\w+\.js)/ && parsed_vars['oauthClientId'].blank?
      parsed_vars['oauthClientId'] = get_generated_client_id $1
    end

    raise "Failed to parse login variables" if parsed_vars.empty?
    parsed_vars
  end

  def get_generated_client_id url
    response = `curl #{url}`
    return $1 if response =~ /PRODUCTION:return"(\w+)";/
  end

  def set_account_token username, password, security_code=nil
    if session[:robinhood_oauth_client_id].blank?
      login_vars = get_login_variables
      #default_client_id = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS'
      #  it seems the device token can be any hexadecimal numbers in the following format
      default_device_token = '1234567a-1234-1234-1234-123456789012'
      session[:robinhood_oauth_client_id] = login_vars['oauthClientId']
      session[:robinhood_device_token] ||= login_vars['clientId'] || default_device_token
    end
    opts = {
      client_id: session[:robinhood_oauth_client_id],
      device_token: session[:robinhood_device_token],
      expires_in: 86400,
      grant_type: 'password',
      password: password,
      scope: "internal",
      token_request_path: "/login",
      username: username,



    }
    opts["mfa_code"] = security_code if security_code.present?
    response = robinhood_post "#{ROBINHOOD_API_URL}/oauth2/token/", opts
    
    if response["accept_challenge_types"]
      opts[:challenge_type] = "sms" # can also do 'email'
      challenge_request_details = robinhood_post("#{ROBINHOOD_API_URL}/oauth2/token/", opts)
      session[:robinhood_challenge_id] = challenge_request_details["challenge"]["id"]
    elsif !response["mfa_required"]
      raise "Missing device token" unless session[:robinhood_device_token].present?
      set_oauth_token(response)
      get_user
      session[:robinhood_id] = @user["id"]
    end
    response
  end

  def complete_challenge code
    raise "Missing challenge ID" unless session[:robinhood_challenge_id].present?
    response = robinhood_post "#{ROBINHOOD_API_URL}/challenge/#{session[:robinhood_challenge_id]}/respond/", {response: code}
    response["status"] == 'validated'
  end

  def oauth_token_valid?
    session[:robinhood_oauth].present? && session[:robinhood_oauth_expiration].present? && session[:robinhood_oauth_expiration] > Time.now
  end

  def set_oauth_token(response)
    return if oauth_token_valid?
    if session[:robinhood_oauth_refresh].present?
      # TODO not working....
      #refresh_oauth_token
      #return
    end
    return unless response["access_token"].present?
    session[:robinhood_oauth] = response["access_token"]
    session[:robinhood_oauth_expiration] = Time.now + response["expires_in"].seconds
    session[:robinhood_oauth_refresh] = response["refresh_token"]
  end

  def refresh_oauth_token
    # TODO this doesnt seem to be working
    return unless session[:robinhood_oauth_refresh].present?
    response = robinhood_post "#{ROBINHOOD_API_URL}/oauth2/token/", {
      grant_type: 'refresh_token',
      refresh_token: session[:robinhood_oauth_refresh]
    }
    raise response.to_s
  end

  def get_positions
    @positions = get_all_results(robinhood_get "#{ROBINHOOD_API_URL}/positions/?nonzero=true")
  end
  # options
  # https://api.robinhood.com/options/aggregate_positions/?account_numbers=5SE30723&nonzero=True
  def get_aggregate_positions
    url = "#{ROBINHOOD_API_URL}/options/aggregate_positions/?nonzero=true"
    puts "Getting aggregate positions from #{url}"
    @aggregate_positions = get_all_results(robinhood_get("#{ROBINHOOD_API_URL}/options/aggregate_positions/?nonzero=true"))
    puts "Got #{@aggregate_positions}"
  end

  def reorder_portfolio_positions instrument_ids
    robinhood_get("#{ROBINHOOD_API_URL}/positions/?ordering=#{instrument_ids.join ','}")
  end

  def get_portfolios
    @portfolios = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/portfolios/")
  end

  def get_watchlists
    @watchlists = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/watchlists/")
  end

  def create_new_watchlist name
    # this endpoint seemingly doesnt work
    robinhood_post "#{ROBINHOOD_API_URL}/watchlists/", {name: name}
  end

  def reorder_watchlist name, instrument_ids
    robinhood_post "#{ROBINHOOD_API_URL}/watchlists/#{name}/reorder/", {uuids: instrument_ids.join(",")}
  end

  def add_symbols_to watchlist_name, symbols
    robinhood_post "#{ROBINHOOD_API_URL}/watchlists/#{watchlist_name}/bulk_add/", {symbols: symbols.join(",")}
  end

  def remove_symbol_from watchlist_name, id
    robinhood_delete "#{ROBINHOOD_API_URL}/watchlists/#{watchlist_name}/#{id}/"
  end

  def get_quotes(symbols)
    @quotes = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/quotes/?symbols=#{symbols.join(',')}")
  end

  def get_dividends
    @dividends = get_all_results robinhood_get "#{ROBINHOOD_API_URL}/dividends/"
  end

  def get_documents
    @documents = get_all_results robinhood_get "#{ROBINHOOD_API_URL}/documents/"
  end

  def get_markets
    @markets = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/markets/")
    @markets.delete_if{|m| m["mic"] !~ /(xnys|xnas)/i }
    @markets.each do |market|
      market.merge! robinhood_get(market["todays_hours"])
      if !market["opens_at"]
        next_open = robinhood_get(market["next_open_hours"])
        market["opens_at"] = next_open["opens_at"]
        market["closes_at"] = next_open["closes_at"]
      else
        closes = DateTime.parse market["closes_at"]
        if closes < Time.now
          next_open = robinhood_get(market["next_open_hours"])
          market["opens_at"] = next_open["opens_at"]
          market["closes_at"] = next_open["closes_at"]
        end
      end
    end
  end

  def get_transfers
    @transfers = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/ach/transfers/")
  end

  def get_ach_accounts
    @ach_accounts = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/ach/relationships/")
  end

  def get_news symbol
    @news = robinhood_get "#{ROBINHOOD_API_URL}/midlands/news/#{symbol.upcase}/"
  end

  def get_sp500_movers direction
    @movers = robinhood_get "#{ROBINHOOD_API_URL}/midlands/movers/sp500/?direction=#{direction}"
  end

  # days have a range of  1 to 21, but 21 days is a LOT! typically don't do > 7
  def get_companies_reporting_earnings_within days
    @earnings = robinhood_get("#{ROBINHOOD_API_URL}/marketdata/earnings/?range=#{days}day")["results"]
  end

  def get_earnings symbol
    @earnings = robinhood_get("#{ROBINHOOD_API_URL}/marketdata/earnings/?symbol=#{symbol}")["results"]
  end

  def next_earnings_report symbol
    get_earnings symbol
    @earnings = @earnings.find{|e| DateTime.parse(e["report"]["date"]) >= Time.now.beginning_of_day if e["report"].present?}
  end

  # GET /quotes/historicals/$symbol/[?interval=$i&span=$s&bounds=$b] interval=week|day|10minute|5minute|null(all) span=day|week|year|5year|all bounds=extended|regular|trading
  # only certain combos work, such as:
  # get_history :AAPL, "5minute", {span: "day"}
  # get_history :AAPL, "10minute", {span: "week"}
  # get_history :AAPL, "day", {span: "year"}
  # get_history :AAPL, "week", {span: "5year"}
  def get_history symbol, interval, opts={}
    is_month = opts[:span] =~ /month/i
    if is_month
      # month isn't supported? use year instead
      interval = "day"
      opts[:span] = "year"
    end
    url = "#{ROBINHOOD_API_URL}/quotes/historicals/#{symbol}/?interval=#{interval}"
    opts.each do |k,v|
      url += "&#{k}=#{v}"
    end
    @history = robinhood_get url
    if is_month
      @history["historicals"] = @history["historicals"].select{ |data| DateTime.parse(data["begins_at"]) > 1.month.ago}
    end
  end

  def get_portfolio_history account, interval, opts={}
    is_month = opts[:span] =~ /month/i
    if is_month
      # month isn't supported? use year instead
      interval = "day"
      opts[:span] = "year"
    end
    url = "#{ROBINHOOD_API_URL}/portfolios/historicals/#{account}/?interval=#{interval}"
    opts.each do |k,v|
      url += "&#{k}=#{v}"
    end
    @portfolio_history = robinhood_get(url)
    if is_month
      @portfolio_history["equity_historicals"] = @portfolio_history["equity_historicals"].select{ |data| DateTime.parse(data["begins_at"]) > 1.month.ago}
    end
  end

  def get_orders
    @orders = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/orders/")
  end

  def place_order data
    robinhood_post "#{ROBINHOOD_API_URL}/orders/", data
  end

  def get_fundamentals symbols
    @fundamentals ||= {}
    symbols.each_with_index do |symbol,i|
      @fundamentals[symbol.upcase] = robinhood_get("#{ROBINHOOD_API_URL}/fundamentals/?symbols=#{symbol.upcase}")["results"].try(:first)
    end
  end

  def get_cards
    @cards = robinhood_get("#{ROBINHOOD_API_URL}/midlands/notifications/stack/")["results"]
    # show newest first
    now = Time.now.to_s
    @cards.sort!{|a,b| DateTime.parse(b["time"] || now) <=> DateTime.parse(a["time"] || now)}
  end
  
  def dismiss_notification notification_url
    id = notification_url.split('/').last.to_s
    response = robinhood_post "#{ROBINHOOD_API_URL}/midlands/notifications/stack/#{id}/dismiss/", {}
    response.empty?
  end

  def get_user
    @user = robinhood_get "#{ROBINHOOD_API_URL}/user/"
  end

  def get_accounts
    @accounts = robinhood_get("#{ROBINHOOD_API_URL}/accounts/")["results"]
  end

  # TODO this should probably move elsewhere
  def portfolio_line_chart interval="5minute", opts={span: "day"}
    get_portfolio_history get_accounts.first["account_number"], interval, opts
    columns = [ {role: :none, data: ['number', 'X']} ] # add x axis

    # each stock has a value and a tooltip
    columns = columns + 
      [
       {role: :none, data: ['number', "Portfolio"]},
       {role: :tooltip, data: {type: :string, role: :tooltip}}
      ]

    rows = []
    @portfolio_history["equity_historicals"].each_with_index do |h,i|
      rows[i] ||= [i+1]
      price = (opts[:span] == "day" ? h["adjusted_open_equity"] : h["adjusted_close_equity"]).to_f
      date = h["begins_at"].in_time_zone('EST').strftime '%m/%d/%y %l:%M%P'
      rows[i] = rows[i] + [price, "$#{price} on #{date}"]
    end
    
    previous_close_price = @portfolio_history["adjusted_previous_close_equity"].to_f
    previous_close_price = @portfolio_history["equity_historicals"].first["adjusted_open_equity"].to_f if previous_close_price == 0.0
    most_recent_price = @portfolio_history["equity_historicals"].last["adjusted_open_equity"].to_f
    color = most_recent_price > previous_close_price ? ROBINHOOD_GREEN : ROBINHOOD_ORANGE
    options = {
      #title: "Price chart",
      hAxis: {
        #title: 'Date',
        ticks: 'none', #rows.map{ |r| r.first },
        gridlines: {color: "transparent"}
      },
      vAxis: {
        #title: 'Price',
        gridlines: {color: "transparent"}
      },
      focusTarget: :category, # show all tooltips for column on hover,
      #curveType: :function, # curve lines, comment out to disable
      legend: :none,
      chartArea: { width: '90%', height: '75%' },
      series: {"0": {color: color}},
      backgroundColor: "#090d16"
    }
    
    {columns: columns, rows: rows, options: options}
  end

  def stock_line_chart symbol, interval="5minute", opts={span: "day"}
    get_history symbol, interval, opts
    columns = [ {role: :none, data: ['number', 'X']} ] # add x axis

    # each stock has a value and a tooltip
    columns = columns + 
      [
       {role: :none, data: ['number', symbol]},
       {role: :tooltip, data: {type: :string, role: :tooltip}}
      ]

    rows = []
    last_price = 0.0
    @history["historicals"].each_with_index do |h,i|
      rows[i] ||= [i+1]
      rows[i] = rows[i] + [h["close_price"].to_f, h["begins_at"]]
      last_price = h["close_price"].to_f
    end

    color = @history["previous_close_price"].to_f < last_price ? ROBINHOOD_GREEN : ROBINHOOD_ORANGE
    options = {
      #title: "Price chart",
      hAxis: {
        #title: 'Date',
        ticks: 'none', #rows.map{ |r| r.first },
        gridlines: {color: "transparent"}
      },
      vAxis: {
        #title: 'Price',
        gridlines: {color: "transparent"}
      },
      focusTarget: :category, # show all tooltips for column on hover,
      #curveType: :function, # curve lines, comment out to disable
      legend: :none,
      chartArea: { width: '90%', height: '75%' },
      series: {"0": {color: color}},
      backgroundColor: "#090d16"
    }
    
    {columns: columns, rows: rows, options: options}
  end

  # TODO move this elsewhere
  def get_price_intersections history
    close_prices = history["historicals"].map{|h| h["close_price"].to_f}
    period_one = 50
    period_two = 200
    periods = [period_one, period_two].sort!
    shorter_sma = simple_moving_average(close_prices, periods.first)
    longer_sma = simple_moving_average(close_prices, periods.last)
    combined = longer_sma.reverse.map.with_index{|longer,i| {shorter_sma: shorter_sma[(i*-1)-1], longer_sma: longer}}
    combined.each_with_index do |data,i|
      data[:current_price] = history["historicals"][(i*-1)-1]["close_price"].to_f
      data[:date] = history["historicals"][(i*-1)-1]["begins_at"]
    end
    combined.reverse!
    prev_change = combined.first[:shorter_sma] / combined.first[:longer_sma] - 1
    combined.each_with_index do |data,i|
      next if i == 0
      change = data[:shorter_sma] / data[:longer_sma] - 1
      if prev_change.negative? && change.positive?
        # upward trend
        data[:action] = :buy
      end
      if prev_change.positive? && change.negative?
        # downward trend
        data[:action] = :sell
      end
      prev_change = change
    end
    raise combined.select{|data| data[:action].present?}.to_s
  end

  def get_experiments
    @experiments = robinhood_get "https://analytics.robinhood.com/experiments/"
    @experiments.each do |experiment|
      experiment['enabled'] = participating_in_experiment? experiment['experiment_name']
    end
  end

  def participating_in_experiment? experiment_name
    robinhood_get "https://analytics.robinhood.com/experiments/#{experiment_name}/participant/"
  end

  def get_instruments query
    @instruments = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/instruments/?query=#{query}")
  end

  def instrument_from_symbol symbol
    robinhood_get("#{ROBINHOOD_API_URL}/instruments/?symbol=#{symbol}")["results"].first
  end

  def get_splits instrument_id
    @splits = Rails.cache.fetch("#{instrument_id}_splits", expires_in: 12.hours) do
      get_all_results robinhood_get("#{ROBINHOOD_API_URL}/instruments/#{instrument_id}/splits/")
    end
  end

  # CRYPTO

  def get_crypto_portfolios
    @crypto_portfolios = get_all_results robinhood_get("#{ROBINHOOD_CRYPTO_URL}/portfolios/")
  end

  def get_crypto_portfolio id
    robinhood_get "#{ROBINHOOD_CRYPTO_URL}/portfolios/#{id}/"
  end

  def get_crypto_holdings
    @crypto_holdings = get_all_results robinhood_get("#{ROBINHOOD_CRYPTO_URL}/holdings/")
  end

  def get_crypto_watchlists
    @crypto_watchlists = get_all_results robinhood_get("#{ROBINHOOD_CRYPTO_URL}/watchlists/")
  end

  def get_crypto_watchlist id
    robinhood_get("#{ROBINHOOD_CRYPTO_URL}/watchlists/#{id}/")
  end

  def set_crypto_watchlist id, pair_ids
    robinhood_patch "#{ROBINHOOD_CRYPTO_URL}/watchlists/#{id}/", {currency_pair_ids: pair_ids}
  end

  def get_crypto_pairs
    @crypto_pairs = get_all_results robinhood_get("#{ROBINHOOD_CRYPTO_URL}/currency_pairs/")
  end
  
  def get_crypto_pair id
    robinhood_get "#{ROBINHOOD_CRYPTO_URL}/currency_pairs/#{id}/"
  end

  def get_crypto_pair_quotes ids
    @crypto_quotes = get_all_results robinhood_get("#{ROBINHOOD_API_URL}/marketdata/forex/quotes/?ids=#{ids.join(',')}")
  end

  def get_cryptocurrencies
    @cryptocurrencies = robinhood_get "#{ROBINHOOD_CRYPTO_URL}/currencies/"
  end

  def get_cryptocurrency id
    robinhood_get "#{ROBINHOOD_CRYPTO_URL}/currencies/#{id}/"
  end

  def get_crypto_halts
    robinhood_get "#{ROBINHOOD_CRYPTO_URL}/halts/"
  end

  def get_crypto_history id
    robinhood_get "#{ROBINHOOD__CRYPTO_URL}/marketdata/forex/historicals/#{id}/"
  end

  def get_crypto_orders
    @crypto_orders = get_all_results robinhood_get("#{ROBINHOOD_CRYPTO_URL}/orders/")
  end

  def activate_crypto_account data
    robinhood_post "#{ROBINHOOD_CRYPTO_URL}/activations/", data
  end

  def get_crypto_account_activations
    @crypto_activations = get_all_results robinhood_get("#{ROBINHOOD_CRYPTO_URL}/activations/")
  end

  # GENERAL

  def get_all_results response, params=""
    results = response["results"]
    next_page = response["next"]
    while next_page.present?
      response = robinhood_get next_page + params
      results += response["results"]
      next_page = response["next"]
    end
    results
  end

  def robinhood_post url, data
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, initheader=robinhood_headers(url))
    #request.set_form_data(data)
    request.body = data.to_json
    request['content-type'] = 'application/json'
    response = http.request(request)
    JSON.parse(response.body)
  end

  def robinhood_patch url, data
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Patch.new(uri.request_uri, initheader=robinhood_headers(url))
    request.body = data.to_json
    request['content-type'] = 'application/json'
    response = http.request(request)
    JSON.parse(response.body)
  end

  def robinhood_delete url
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Delete.new(uri.request_uri, initheader=robinhood_headers(url))
    response = http.request(request)
  end

  def robinhood_get(url)
    puts "robinhood_get: #{url}"
    puts "caller: #{caller_locations(1,1)[0].label}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri, initheader=robinhood_headers(url))
    response = http.request(request)
    JSON.parse(response.body)
#     irb(main):010:0> Rails.cache.fetch("_session_id:2::908a2cb4e5aa5fa5a5eb6148eb6fb72b16e551d4bd1aa8eeda449f14a730cea9")
# => 
# {"_csrf_token"=>"o57ZX5Ml7RXuzcm28a0VUvQwpGVgxsJTTcr9wtDZ6CM",
#  "robinhood_oauth_client_id"=>"c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS",
#  "robinhood_device_token"=>"1234567a-1234-1234-1234-123456789012",
#  "robinhood_oauth"=>
#   "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJkY3QiOjE2ODY5NzAxNDYsImRldmljZV9oYXNoIjoiOTZmNmQxNzYyMzMzYjE0MDUwMzY5N2ExZGIwOWZkNGMiLCJleHAiOjE2ODc0NzQ1NjIsImxldmVsMl9hY2Nlc3MiOmZhbHNlLCJtZXRhIjp7Im9pZCI6ImM4MlNIMFdaT3NhYk9YR1Ayc3hxY2ozNEZ4a3ZmbldSWkJLbEJqRlMiLCJvbiI6IlJvYmluaG9vZCJ9LCJvcHRpb25zIjp0cnVlLCJzY29wZSI6ImludGVybmFsIiwic2VydmljZV9yZWNvcmRzIjpbeyJoYWx0ZWQiOmZhbHNlLCJzZXJ2aWNlIjoibnVtbXVzX3VzIiwic2hhcmRfaWQiOjEsInN0YXRlIjoiYXZhaWxhYmxlIn0seyJoYWx0ZWQiOmZhbHNlLCJzZXJ2aWNlIjoiYnJva2ViYWNrX3VzIiwic2hhcmRfaWQiOjQsInN0YXRlIjoiYXZhaWxhYmxlIn1dLCJzcm0iOnsiYl91cyI6eyJobCI6ZmFsc2UsInNpZCI6NCwic3QiOiJhdiJ9LCJuX3VzIjp7ImhsIjpmYWxzZSwic2lkIjoxLCJzdCI6ImF2In19LCJ0b2tlbiI6Ijh4R2ZhMEUwZ2xKYVZra3BGWWZYQUJUekZtV2tOViIsInVzZXJfaWQiOiI0ZjBkYzIzZi00NGJhLTQ0NTctYjA2Yy1lNTk5OTA0OTE5MjIiLCJ1c2VyX29yaWdpbiI6IlVTIn0.nxNIl7hAvf5gGeLzO4cOSagAzULB7XCwrwVpOsoxT_UUK--G0ejmwoOaNGBFny0zH7EpIJ0xzsROsAAm5EcovjAr_gdqFxAvobL45JPRC0aMA3fwrkLgti9n6GxTwPHGJnV2oR_kWR5ZVvaKszjiJDuCzdi6Bh4xSc2NR2LktzNhsdl8ADV_ueC9-DZuBzLk6-IEK4vDZyqTW94w3V0MtoxetDhmtVEy7lIkLvHN3Vouz2LQAyKQ_nlYTqQ7YCO3O4V4_ukXc_l1LZfQ_u-hWNOKoru_Y1IAPeqUOtn5JBWoMGxfaXyWqn_98_zNMJvIedltF5SJPOMA2VuAPfa4ow",
#  "robinhood_oauth_expiration"=>2023-06-22 22:56:02.1885379 +0000,
#  "robinhood_oauth_refresh"=>"3rUWy6da9MFZEtZ4Ofkuvj0UQPvcI6",
#  "robinhood_id"=>"4f0dc23f-44ba-4457-b06c-e59990491922"}
  end

  def find_or_create_instrument(url)
    puts "find_or_create_instrument: #{url}"
    puts "caller: #{caller_locations(1,1)[0].label}"
    instrument = Instrument.find_by url: url
    if instrument.nil?
      instrument_data =  robinhood_get url
      instrument = Instrument.create!(
                                      name: instrument_data["name"],
                                      url: instrument_data["url"],
                                      quote_url: instrument_data["quote"],
                                      symbol: instrument_data["symbol"],
                                      fundamentals_url: instrument_data["fundamentals"],
                                      robinhood_id: instrument_data["id"]
                                      )
    end
    instrument
  end

  private

  def robinhood_headers url
    headers = {
      "Accept" => 'application/json'
    }
    if session[:robinhood_challenge_id].present?
      headers['X-ROBINHOOD-CHALLENGE-RESPONSE-ID'] = session[:robinhood_challenge_id]
    end
    if oauth_token_valid? && url !~ /migrate_token/i
      headers["Authorization"] = "Bearer #{session[:robinhood_oauth]}"
    end
    headers
  end
end
