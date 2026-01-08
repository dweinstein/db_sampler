import Config

# Test config - use mock adapter
config :db_sampler,
  config_adapter: DbSampler.Config.TestAdapter
