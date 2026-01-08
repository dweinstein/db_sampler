defmodule DbSampler.Database do
  @moduledoc """
  Facade module providing a safe, easy-to-use interface for database operations.
  Uses the configured adapter (defaults to DefaultAdapter).
  Implements the Database.Adapter behaviour.
  """

  @behaviour DbSampler.Database.Adapter

  alias DbSampler.Config
  alias DbSampler.Database.Result

  @default_timeout 15_000

  defp adapter, do: Config.database_adapter()
  defp default_conn, do: Config.database_conn()

  @impl true
  def start_link(opts \\ []) do
    adapter().start_link(opts)
  end

  @impl true
  def query(conn, sql, params \\ [], opts \\ []) do
    opts = Keyword.put_new(opts, :timeout, @default_timeout)
    adapter().query(conn, sql, params, opts)
  end

  @impl true
  def query!(conn, sql, params \\ [], opts \\ []) do
    opts = Keyword.put_new(opts, :timeout, @default_timeout)
    adapter().query!(conn, sql, params, opts)
  end

  @impl true
  def transaction(conn, fun, opts \\ []) do
    opts = Keyword.put_new(opts, :timeout, @default_timeout)
    adapter().transaction(conn, fun, opts)
  end

  # Convenience functions using default connection

  @doc """
  Execute a SQL query using the default connection.

  ## Parameters

    * `sql` - SQL query string
    * `params` - List of query parameters (default: `[]`)
    * `opts` - Query options (default: `[]`)

  ## Options

    * `:timeout` - Query timeout in milliseconds (default: 15000)

  ## Returns

    * `{:ok, %DbSampler.Database.Result{}}` - On success
    * `{:error, exception}` - On failure
  """
  @spec run_query(String.t(), list(), keyword()) :: {:ok, Result.t()} | {:error, Exception.t()}
  def run_query(sql, params \\ [], opts \\ []) do
    query(default_conn(), sql, params, opts)
  end

  @doc """
  Execute a SQL query using the default connection, raising on error.

  Same as `run_query/3` but raises on failure.
  """
  @spec run_query!(String.t(), list(), keyword()) :: Result.t()
  def run_query!(sql, params \\ [], opts \\ []) do
    query!(default_conn(), sql, params, opts)
  end

  @doc """
  Execute a function within a database transaction using the default connection.

  ## Parameters

    * `fun` - Function to execute within the transaction
    * `opts` - Transaction options (default: `[]`)

  ## Returns

    * `{:ok, result}` - Transaction committed, returns function result
    * `{:error, reason}` - Transaction rolled back
  """
  @spec run_transaction((DBConnection.t() -> result), keyword()) ::
          {:ok, result} | {:error, term()}
        when result: var
  def run_transaction(fun, opts \\ []) do
    transaction(default_conn(), fun, opts)
  end

  @doc """
  Execute a SQL query and return rows as a list of maps.

  Converts the result into a list of maps where keys are column names.

  ## Parameters

    * `sql` - SQL query string
    * `params` - List of query parameters (default: `[]`)
    * `opts` - Query options (default: `[]`)

  ## Returns

    * `{:ok, [map()]}` - List of rows as maps
    * `{:error, exception}` - On failure
  """
  @spec fetch_rows(String.t(), list(), keyword()) :: {:ok, [map()]} | {:error, Exception.t()}
  def fetch_rows(sql, params \\ [], opts \\ []) do
    case run_query(sql, params, opts) do
      {:ok, %Result{rows: rows, columns: columns}} ->
        {:ok, rows_to_maps(columns, rows)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Execute a SQL query and return rows as a list of maps, raising on error.

  Same as `fetch_rows/3` but raises on failure.
  """
  @spec fetch_rows!(String.t(), list(), keyword()) :: [map()]
  def fetch_rows!(sql, params \\ [], opts \\ []) do
    %Result{rows: rows, columns: columns} = run_query!(sql, params, opts)
    rows_to_maps(columns, rows)
  end

  defp rows_to_maps(columns, rows) do
    Enum.map(rows, fn row ->
      columns
      |> Enum.zip(row)
      |> Map.new()
    end)
  end
end
