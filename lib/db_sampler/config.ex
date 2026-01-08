defmodule DbSampler.Config do
  @moduledoc false

  @behaviour DbSampler.Config.Adapter

  defp adapter do
    Application.get_env(:db_sampler, :config_adapter, DbSampler.Config.DefaultAdapter)
  end

  @impl true
  @spec database_url() :: String.t()
  def database_url, do: adapter().database_url()

  @impl true
  @spec database_adapter() :: module()
  def database_adapter, do: adapter().database_adapter()

  @impl true
  @spec database_conn() :: atom()
  def database_conn, do: adapter().database_conn()
end
