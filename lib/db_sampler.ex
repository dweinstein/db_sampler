defmodule DbSampler do
  @moduledoc """
  Database sampling tool for exporting table data to NDJSON.

  This is the main entry point for the DbSampler library. It delegates to
  `DbSampler.Sampler` for the actual implementation.

  ## Modes

  - **Table mode**: Sample rows from a table with limit/ordering
  - **SQL mode**: Execute arbitrary SQL from .sql.eex template files

  ## Quick Start

      # Sample from a table
      {:ok, rows} = DbSampler.sample_table("users", limit: 100)

      # Export to file
      {:ok, count} = DbSampler.export_table("users", "users.ndjson", limit: 100)

      # Execute SQL file
      {:ok, rows} = DbSampler.query_file("queries/report.sql.eex")

  ## CLI Usage

  DbSampler also provides a Mix task for command-line usage:

      mix sample --table users --limit 100 --output users.ndjson
      mix sample --sql queries/report.sql.eex

  See `Mix.Tasks.Sample` for full CLI documentation.
  """

  @doc """
  Sample rows from a database table.

  ## Options
    * `:limit` - Number of rows to sample (default: 100)
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:order_by` - ORDER BY clause (e.g., "updated_at DESC")
  """
  @spec sample_table(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  defdelegate sample_table(table, opts \\ []), to: DbSampler.Sampler

  @doc """
  Sample rows from a table and write to NDJSON file.

  Returns `{:ok, row_count}` on success.

  ## Options
    * `:limit` - Number of rows to sample (default: 100)
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:order_by` - ORDER BY clause
  """
  @spec export_table(String.t(), Path.t(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  defdelegate export_table(table, output_path, opts \\ []), to: DbSampler.Sampler

  @doc """
  Execute raw SQL and return rows as list of maps.

  ## Options
    * `:params` - List of query parameters for $1, $2, etc. (default: [])
    * `:timeout` - Query timeout in ms (default: 60_000)

  ## Examples

      {:ok, rows} = DbSampler.query("SELECT * FROM users LIMIT 10")

      {:ok, rows} = DbSampler.query(
        "SELECT * FROM users WHERE status = $1",
        params: ["active"]
      )
  """
  @spec query(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  defdelegate query(sql, opts \\ []), to: DbSampler.Sampler

  @doc """
  Read a .sql.eex file, evaluate EEx template, and execute the SQL.

  ## Options
    * `:params` - List of query parameters for $1, $2, etc. (default: [])
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:assigns` - Variables to pass to EEx template

  ## Built-in Template Variables
    * `@dev` - true if MIX_ENV=dev
    * `@test` - true if MIX_ENV=test
    * `@prod` - true if MIX_ENV=prod
    * `@date` - current UTC date

  ## Examples

      {:ok, rows} = DbSampler.query_file("queries/report.sql.eex")

      {:ok, rows} = DbSampler.query_file("queries/report.sql.eex",
        params: ["active"],
        assigns: [limit: 100]
      )
  """
  @spec query_file(Path.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  defdelegate query_file(path, opts \\ []), to: DbSampler.Sampler

  @doc """
  Read a .sql.eex file, execute it, and write results to NDJSON file.

  Returns `{:ok, row_count}` on success.

  ## Options
    * `:params` - List of query parameters for $1, $2, etc. (default: [])
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:assigns` - Variables to pass to EEx template
  """
  @spec export_query_file(Path.t(), Path.t(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  defdelegate export_query_file(sql_path, output_path, opts \\ []), to: DbSampler.Sampler

  # ===========================================================================
  # Streaming API
  # ===========================================================================

  @doc """
  Execute a function with streaming database support.

  The function receives the database connection which must be passed
  to streaming functions.

  ## Example

      DbSampler.with_stream(fn conn ->
        conn
        |> DbSampler.stream_table("users", limit: 10_000)
        |> Stream.each(&IO.inspect/1)
        |> Stream.run()
      end)
  """
  defdelegate with_stream(fun, opts \\ []), to: DbSampler.Database

  @doc """
  Stream rows from a database table.

  Must be called within `with_stream/2`. Returns a stream that yields
  one row (as map) at a time.

  ## Parameters
    * `conn` - Database connection from `with_stream/2` callback
    * `table` - Table name to stream from

  ## Options
    * `:limit` - Number of rows to stream (default: 100)
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:order_by` - ORDER BY clause
    * `:max_rows` - Rows per chunk from database (default: 500)
  """
  @spec stream_table(DBConnection.t(), String.t(), keyword()) :: Enumerable.t()
  defdelegate stream_table(conn, table, opts \\ []), to: DbSampler.Sampler

  @doc """
  Stream rows from a table directly to NDJSON file.

  Memory-efficient for large exports - streams rows directly to file
  without loading all into memory.

  Returns `{:ok, row_count}` on success.

  ## Options
    * `:limit` - Number of rows to stream (default: 100)
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:order_by` - ORDER BY clause
    * `:max_rows` - Rows per chunk from database (default: 500)
  """
  @spec export_table_stream(String.t(), Path.t(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  defdelegate export_table_stream(table, output_path, opts \\ []), to: DbSampler.Sampler

  @doc """
  Stream SQL file results directly to NDJSON file.

  Memory-efficient for large exports.

  ## Options
    * `:params` - Query parameters (default: [])
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:assigns` - EEx template variables
    * `:max_rows` - Rows per chunk (default: 500)
  """
  @spec export_query_file_stream(Path.t(), Path.t(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  defdelegate export_query_file_stream(sql_path, output_path, opts \\ []), to: DbSampler.Sampler
end
