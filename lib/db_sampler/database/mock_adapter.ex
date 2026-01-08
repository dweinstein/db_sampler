defmodule DbSampler.Database.MockAdapter do
  @moduledoc false

  @behaviour DbSampler.Database.Adapter

  alias DbSampler.Database.Result

  @impl true
  def start_link(_opts) do
    {:ok, self()}
  end

  @impl true
  def query(_conn, sql, params \\ [], _opts \\ []) do
    result = handle_query(sql, params)
    {:ok, result}
  end

  @impl true
  def query!(_conn, sql, params \\ [], _opts \\ []) do
    handle_query(sql, params)
  end

  @impl true
  def transaction(_conn, fun, _opts \\ []) do
    {:ok, fun.(nil)}
  end

  defp handle_query(sql, params) do
    # Try to get limit from params first, then parse from SQL
    limit = List.first(params) || parse_limit_from_sql(sql) || 10
    build_sample_result(limit)
  end

  defp parse_limit_from_sql(sql) do
    case Regex.run(~r/LIMIT\s+(\d+)/i, sql) do
      [_, limit_str] -> String.to_integer(limit_str)
      _ -> nil
    end
  end

  defp build_sample_result(limit) do
    rows =
      1..limit
      |> Enum.map(&build_sample_row/1)

    Result.new(
      ["id", "name", "email", "active", "created_at", "updated_at"],
      rows
    )
  end

  defp build_sample_row(index) do
    now = DateTime.utc_now()
    created_at = DateTime.add(now, -index * 86400, :second)

    [
      generate_uuid(),
      "User #{index}",
      "user#{index}@example.com",
      rem(index, 3) != 0,
      created_at,
      created_at
    ]
  end

  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    <<a::32, b::16, 4::4, c::12, 2::2, d::14, e::48>>
    |> Base.encode16(case: :lower)
    |> String.replace(~r/(.{8})(.{4})(.{4})(.{4})(.{12})/, "\\1-\\2-\\3-\\4-\\5")
  end
end
