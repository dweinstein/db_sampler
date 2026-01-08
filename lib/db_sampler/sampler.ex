defmodule DbSampler.Sampler do
  @moduledoc """
  Core logic for sampling rows from database tables and exporting to NDJSON.

  Supports two modes:
  - Table mode: `sample_table/2` - sample rows from a table with limit/order
  - SQL mode: `query_file/2` - execute arbitrary SQL from .sql.eex files

  ## Table Mode

      {:ok, rows} = Sampler.sample_table("users", limit: 100)
      {:ok, count} = Sampler.export_table("users", "users.ndjson", limit: 100)

  ## SQL Mode

      {:ok, rows} = Sampler.query("SELECT * FROM users LIMIT 10")
      {:ok, rows} = Sampler.query_file("queries/report.sql.eex", assigns: [limit: 100])
      {:ok, count} = Sampler.export_query_file("queries/report.sql.eex", "output.ndjson")
  """

  alias DbSampler.Database

  @default_limit 100
  @default_timeout 60_000

  # =============================================================================
  # Public API - Table Mode
  # =============================================================================

  @doc """
  Sample rows from a database table.

  ## Options
    * `:limit` - Number of rows to sample (default: 100)
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:order_by` - ORDER BY clause (e.g., "updated_at DESC")
  """
  @spec sample_table(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def sample_table(table, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    order_by = Keyword.get(opts, :order_by)

    sql =
      if order_by do
        "SELECT * FROM #{table} ORDER BY #{order_by} LIMIT $1"
      else
        "SELECT * FROM #{table} LIMIT $1"
      end

    case Database.fetch_rows(sql, [limit], timeout: timeout) do
      {:ok, rows} -> {:ok, rows}
      {:error, _} = error -> error
    end
  end

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
  def export_table(table, output_path, opts \\ []) do
    case sample_table(table, opts) do
      {:ok, rows} -> write_ndjson(rows, output_path)
      {:error, _} = error -> error
    end
  end

  # =============================================================================
  # Public API - SQL Mode
  # =============================================================================

  @doc """
  Execute raw SQL and return rows as list of maps.

  ## Options
    * `:params` - List of query parameters for $1, $2, etc. (default: [])
    * `:timeout` - Query timeout in ms (default: 60_000)

  ## Examples

      # Simple query
      {:ok, rows} = DbSampler.query("SELECT * FROM users LIMIT 10")

      # With parameters
      {:ok, rows} = DbSampler.query(
        "SELECT * FROM users WHERE status = $1 AND created_at > $2",
        params: ["active", ~D[2024-01-01]]
      )
  """
  @spec query(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def query(sql, opts \\ []) do
    params = Keyword.get(opts, :params, [])
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case Database.fetch_rows(sql, params, timeout: timeout) do
      {:ok, rows} -> {:ok, rows}
      {:error, _} = error -> error
    end
  end

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

  ## Example

      # With assigns for template interpolation
      query_file("queries/report.sql.eex", assigns: [table: "users"])

      # With params for parameterized values
      query_file("queries/by_status.sql.eex", params: ["active"])
  """
  @spec query_file(Path.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def query_file(path, opts \\ []) do
    params = Keyword.get(opts, :params, [])
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    assigns = build_assigns(opts)

    with {:ok, template} <- File.read(path),
         sql <- EEx.eval_string(template, assigns: assigns),
         {:ok, rows} <- query(sql, params: params, timeout: timeout) do
      {:ok, rows}
    end
  end

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
  def export_query_file(sql_path, output_path, opts \\ []) do
    case query_file(sql_path, opts) do
      {:ok, rows} -> write_ndjson(rows, output_path)
      {:error, _} = error -> error
    end
  end

  # =============================================================================
  # Public API - Streaming Mode
  # =============================================================================

  @doc """
  Stream rows from a database table.

  Returns a stream that yields one row (as map) at a time.
  Must be consumed within a `Database.with_stream/2` transaction wrapper.

  ## Parameters
    * `conn` - Database connection from `with_stream/2` callback
    * `table` - Table name to stream from

  ## Options
    * `:limit` - Number of rows to stream (default: 100)
    * `:timeout` - Query timeout in ms (default: 60_000)
    * `:order_by` - ORDER BY clause
    * `:max_rows` - Rows per chunk from database (default: 500)

  ## Example

      Database.with_stream(fn conn ->
        conn
        |> Sampler.stream_table("users", limit: 10_000)
        |> Stream.each(&process_row/1)
        |> Stream.run()
      end)
  """
  @spec stream_table(DBConnection.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_table(conn, table, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    order_by = Keyword.get(opts, :order_by)
    stream_opts = Keyword.take(opts, [:timeout, :max_rows])

    sql =
      if order_by do
        "SELECT * FROM #{table} ORDER BY #{order_by} LIMIT $1"
      else
        "SELECT * FROM #{table} LIMIT $1"
      end

    Database.stream_rows(conn, sql, [limit], stream_opts)
  end

  @doc """
  Stream rows from a table and write directly to NDJSON file.

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
  def export_table_stream(table, output_path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    Database.with_stream(
      fn conn ->
        file = File.open!(output_path, [:write, :utf8])

        try do
          count =
            conn
            |> stream_table(table, opts)
            |> Stream.map(&encode_row/1)
            |> Stream.map(&Jason.encode!/1)
            |> Stream.each(fn json -> IO.puts(file, json) end)
            |> Enum.count()

          {:ok, count}
        after
          File.close(file)
        end
      end,
      timeout: timeout
    )
    |> unwrap_transaction_result()
  end

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
  def export_query_file_stream(sql_path, output_path, opts \\ []) do
    params = Keyword.get(opts, :params, [])
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    stream_opts = Keyword.take(opts, [:timeout, :max_rows])
    assigns = build_assigns(opts)

    with {:ok, template} <- File.read(sql_path),
         sql <- EEx.eval_string(template, assigns: assigns) do
      Database.with_stream(
        fn conn ->
          file = File.open!(output_path, [:write, :utf8])

          try do
            count =
              conn
              |> Database.stream_rows(sql, params, stream_opts)
              |> Stream.map(&encode_row/1)
              |> Stream.map(&Jason.encode!/1)
              |> Stream.each(fn json -> IO.puts(file, json) end)
              |> Enum.count()

            {:ok, count}
          after
            File.close(file)
          end
        end,
        timeout: timeout
      )
      |> unwrap_transaction_result()
    end
  end

  defp unwrap_transaction_result({:ok, {:ok, count}}), do: {:ok, count}
  defp unwrap_transaction_result({:ok, {:error, _} = error}), do: error
  defp unwrap_transaction_result({:error, _} = error), do: error

  # =============================================================================
  # Private Functions
  # =============================================================================

  defp build_assigns(opts) do
    custom_assigns = Keyword.get(opts, :assigns, [])

    default_assigns = [
      dev: Mix.env() == :dev,
      test: Mix.env() == :test,
      prod: Mix.env() == :prod,
      date: Date.utc_today()
    ]

    Keyword.merge(default_assigns, custom_assigns)
  end

  defp write_ndjson(rows, output_path) do
    ndjson =
      rows
      |> Enum.map(&encode_row/1)
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    case File.write(output_path, ndjson <> "\n") do
      :ok -> {:ok, length(rows)}
      error -> error
    end
  end

  defp encode_row(row) do
    Map.new(row, fn {k, v} -> {k, encode_value(v)} end)
  end

  defp encode_value(<<_::128>> = uuid) do
    # Binary UUID - convert to string format
    <<a::32, b::16, c::16, d::16, e::48>> = uuid

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end

  defp encode_value(binary) when is_binary(binary) do
    if String.printable?(binary) do
      binary
    else
      Base.encode64(binary)
    end
  end

  defp encode_value(value), do: value
end
