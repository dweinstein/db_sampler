defmodule DbSampler.Database.Adapter do
  @moduledoc false

  alias DbSampler.Database.Result

  @type query_result :: {:ok, Result.t()} | {:error, Exception.t()}
  @type connection :: pid() | atom()
  @type params :: list()

  @callback start_link(opts :: Keyword.t()) :: GenServer.on_start()

  @callback query(
              conn :: connection(),
              statement :: String.t(),
              params :: params(),
              opts :: Keyword.t()
            ) :: query_result()

  @callback query!(
              conn :: connection(),
              statement :: String.t(),
              params :: params(),
              opts :: Keyword.t()
            ) :: Result.t()

  @callback transaction(
              conn :: connection(),
              fun :: (DBConnection.t() -> result),
              opts :: Keyword.t()
            ) :: {:ok, result} | {:error, any()}
            when result: var
end
