defmodule DbSampler.Config.Adapter do
  @moduledoc false

  @callback database_url() :: String.t()
  @callback database_adapter() :: module()
  @callback database_conn() :: atom()
end
