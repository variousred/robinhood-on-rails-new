# The initializers are run early during the Rails boot process, and that might happen before Rails has loaded all of your application code, including the job classes.
# To solve this, use the Rails `config.to_prepare` block. It will delay the execution of your code until after Rails has initialized the application and loaded all classes.

Rails.application.config.to_prepare do
  # check if we are running in a sidekiq worker or rails console. Only run this code if we are not.
  if defined? Rails::Server
    puts("Was not sidekiq server or console")

    # Define a mapping of channels to their respective workers
    CHANNEL_WORKER_MAPPING = {
      # 'TickerChannel' => TickerWorker,
      "PositionsAndQuotesChannel" => PositionsAndQuotesJob,
    }

    scheduler = Rufus::Scheduler.new
    scheduler.every "30s", overlap: false do
      puts("Executing timer task")
      # Get list of currently active subscriptions for each channel
      CHANNEL_WORKER_MAPPING.each do |channel_class_name, worker_class|
        channel_class = Object.const_get(channel_class_name)

        Rails.logger.info("Checking for active subscriptions for: #{channel_class_name}")
        # Rails.logger.info("why is this next line printing twice?")
        Rails.logger.info("active_subscriptions: #{channel_class.active_subscriptions}")
        if channel_class.active_subscriptions.any?
          Rails.logger.info("Found active subscription for: #{channel_class_name}")
          worker_class.perform_async(channel_class.active_subscriptions[0])
        else
          Rails.logger.info("No active subscription found for: #{channel_class_name}")
        end
      end
    end
  end
end
