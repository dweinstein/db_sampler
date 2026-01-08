defmodule DbSampler.Config.DefaultAdapter do
  @moduledoc false

  @behaviour DbSampler.Config.Adapter

  @impl true
  def database_url do
    Application.fetch_env!(:db_sampler, :database_url)
  end

  @impl true
  def database_adapter do
    Application.get_env(:db_sampler, :database_adapter, DbSampler.Database.DefaultAdapter)
  end

  @impl true
  def database_conn do
    Application.get_env(:db_sampler, :database_conn, DbSampler.Repo)
  end
end
