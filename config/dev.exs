import Config

# Dev config - reads DATABASE_URL from environment
# Optional to allow building docs without a database
if database_url = System.get_env("DATABASE_URL") do
  config :db_sampler,
    database_url: database_url
end
