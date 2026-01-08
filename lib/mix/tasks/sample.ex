defmodule Mix.Tasks.Sample do
  @moduledoc """
  Mix task to sample rows from a database and export to NDJSON.

  Supports two modes:
  - **Table mode**: Sample rows from a table with limit/order
  - **SQL mode**: Execute arbitrary SQL from a .sql.eex file

  ## Usage

      mix sample [options]

  ## Table Mode Options

    * `--table`, `-t` - Table to sample (required)
    * `--limit`, `-l` - Number of rows to sample (default: 100)
    * `--order`, `-r` - ORDER BY clause (optional)

  ## SQL Mode Options

    * `--sql`, `-s` - Path to .sql.eex file (enables SQL mode)
    * `--var` - Pass variable to EEx template (can be repeated)

  ## Common Options

    * `--output`, `-o` - Output file path (default: sample.ndjson)
    * `--timeout` - Query timeout in ms (default: 60000)

  ## EEx Template Variables

  SQL files are processed with EEx. Available variables:
    * `@dev` - true if MIX_ENV=dev
    * `@test` - true if MIX_ENV=test
    * `@prod` - true if MIX_ENV=prod
    * `@date` - current UTC date
    * Custom variables via `--var key=value`

  ## Examples

      # Table mode (--table is required)
      mix sample --table users
      mix sample --table public.users --limit 500
      mix sample -t orders -l 100 --order "created_at DESC"

      # SQL mode
      mix sample --sql queries/report.sql.eex
      mix sample --sql queries/report.sql.eex --timeout 300000
      mix sample --sql queries/report.sql.eex --var limit=100 --var days=7
  """

  use Mix.Task

  @shortdoc "Sample rows from database to NDJSON"

  @default_limit 100
  @default_output "sample.ndjson"
  @default_timeout 60_000

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          table: :string,
          limit: :integer,
          output: :string,
          order: :string,
          sql: :string,
          timeout: :integer,
          var: [:string, :keep],
          help: :boolean
        ],
        aliases: [t: :table, l: :limit, o: :output, r: :order, s: :sql, h: :help]
      )

    cond do
      opts[:help] ->
        print_help()

      opts[:sql] ->
        Application.ensure_all_started(:db_sampler)
        output = Keyword.get(opts, :output, @default_output)
        timeout = Keyword.get(opts, :timeout, @default_timeout)
        run_sql_mode(opts[:sql], opts, output, timeout)

      opts[:table] ->
        Application.ensure_all_started(:db_sampler)
        output = Keyword.get(opts, :output, @default_output)
        timeout = Keyword.get(opts, :timeout, @default_timeout)
        run_table_mode(opts, output, timeout)

      true ->
        print_help()
    end
  end

  defp print_help do
    Mix.shell().info("""
    #{@shortdoc}

    Usage: mix sample [options]

    Modes:
      Table mode    Sample rows from a database table (requires --table)
      SQL mode      Execute SQL from a .sql.eex template file (requires --sql)

    Table Mode Options:
      -t, --table TABLE     Table to sample (required)
      -l, --limit N         Number of rows (default: #{@default_limit})
      -r, --order CLAUSE    ORDER BY clause (optional)

    SQL Mode Options:
      -s, --sql PATH        Path to .sql.eex file (enables SQL mode)
      --var KEY=VALUE       Pass variable to EEx template (repeatable)

    Common Options:
      -o, --output PATH     Output file (default: #{@default_output})
      --timeout MS          Query timeout in ms (default: #{@default_timeout})
      -h, --help            Show this help

    Examples:
      mix sample -t users -l 50
      mix sample --table public.orders --limit 100 --order "created_at DESC"
      mix sample --sql queries/report.sql.eex
      mix sample --sql queries/report.sql.eex --var limit=100 --var days=7
    """)
  end

  defp run_table_mode(opts, output, timeout) do
    table = Keyword.fetch!(opts, :table)
    limit = Keyword.get(opts, :limit, @default_limit)
    order_by = Keyword.get(opts, :order)

    Mix.shell().info("Sampling #{limit} rows from #{table}...")

    sample_opts =
      [limit: limit, timeout: timeout]
      |> maybe_add_order_by(order_by)

    case DbSampler.Sampler.export_table(table, output, sample_opts) do
      {:ok, row_count} ->
        Mix.shell().info("Successfully wrote #{row_count} rows to #{output}")

      {:error, %DbSampler.Database.Error{} = error} ->
        Mix.shell().error("Database error: #{Exception.message(error)}")
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.shell().error("Error: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp run_sql_mode(sql_path, opts, output, timeout) do
    unless File.exists?(sql_path) do
      Mix.shell().error("SQL file not found: #{sql_path}")
      exit({:shutdown, 1})
    end

    assigns = parse_vars(Keyword.get_values(opts, :var))

    Mix.shell().info("Executing SQL from #{sql_path}...")

    sample_opts = [timeout: timeout, assigns: assigns]

    case DbSampler.Sampler.export_query_file(sql_path, output, sample_opts) do
      {:ok, row_count} ->
        Mix.shell().info("Successfully wrote #{row_count} rows to #{output}")

      {:error, %DbSampler.Database.Error{} = error} ->
        Mix.shell().error("Database error: #{Exception.message(error)}")
        exit({:shutdown, 1})

      {:error, %EEx.SyntaxError{} = error} ->
        Mix.shell().error("EEx syntax error: #{Exception.message(error)}")
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.shell().error("Error: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp parse_vars(var_strings) do
    Enum.map(var_strings, fn var_string ->
      case String.split(var_string, "=", parts: 2) do
        [key, value] -> {String.to_atom(key), parse_value(value)}
        _ -> raise "Invalid --var format: #{var_string}. Expected key=value"
      end
    end)
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false

  defp parse_value(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp maybe_add_order_by(opts, nil), do: opts
  defp maybe_add_order_by(opts, order_by), do: Keyword.put(opts, :order_by, order_by)
end
