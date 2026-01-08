import Config

# Default config adapter reads from Application env
# Override with :config_adapter for testing
config :db_sampler,
  config_adapter: DbSampler.Config.DefaultAdapter

# Import environment specific config (if it exists)
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
