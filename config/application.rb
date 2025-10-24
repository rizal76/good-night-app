require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Ideally for every environment the config will be different
    # I put here's just to simplicity
    config.default_page = 1
    config.default_per_page = 20
    config.sleep = ActiveSupport::OrderedOptions.new
    config.sleep.min_duration_seconds = 60
    config.sleep_record = ActiveSupport::OrderedOptions.new
    config.sleep_record.cache_duration = 2.minutes
    config.sleep_record.longer_cache_duration = 10.minutes
    config.sleep_record.cache_race_condition_ttl = 30.seconds
    # This rarely change, we use it for getting data feed,
    # We will update this on follow and unfollow action too
    config.sleep_record.cache_following_duration = 1.days
    # This used to differintiate which user that has many following_ids
    # Since we want to handle the query different
    # for lesser we direclty using WHERE IN, but for large this can be slower
    # so we will use JOIN instead
    config.sleep_record.normal_following_count = 100

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
