defmodule DbSampler.Config.TestAdapter do
  @moduledoc false

  @behaviour DbSampler.Config.Adapter

  @impl true
  def database_url do
    "postgresql://test:test@localhost:5432/test_db"
  end

  @impl true
  def database_adapter do
    DbSampler.Database.MockAdapter
  end

  @impl true
  def database_conn do
    DbSampler.TestRepo
  end
end
