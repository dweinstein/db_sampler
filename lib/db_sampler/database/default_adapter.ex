defmodule DbSampler.Database.DefaultAdapter do
  @moduledoc false

  @behaviour DbSampler.Database.Adapter

  alias DbSampler.Database.{Error, Result}

  @impl true
  def start_link(opts) do
    Postgrex.start_link(opts)
  end

  @impl true
  def query(conn, sql, params \\ [], opts \\ []) do
    case Postgrex.query(conn, sql, params, opts) do
      {:ok, result} -> {:ok, Result.from_postgrex(result)}
      {:error, error} -> {:error, Error.wrap(error)}
    end
  end

  @impl true
  def query!(conn, sql, params \\ [], opts \\ []) do
    result = Postgrex.query!(conn, sql, params, opts)
    Result.from_postgrex(result)
  end

  @impl true
  def transaction(conn, fun, opts \\ []) do
    Postgrex.transaction(conn, fun, opts)
  end
end
