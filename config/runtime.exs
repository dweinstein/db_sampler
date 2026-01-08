import Config

if config_env() != :test do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      Example: postgresql://user:password@localhost:5432/database_name
      """

  config :db_sampler,
    database_url: database_url
end
