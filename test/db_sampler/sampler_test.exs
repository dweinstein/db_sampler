defmodule DbSampler.SamplerTest do
  use ExUnit.Case, async: true

  alias DbSampler.Sampler

  @test_queries_dir "test/fixtures/queries"

  setup do
    # Create test fixtures directory
    File.mkdir_p!(@test_queries_dir)
    on_exit(fn -> File.rm_rf!(@test_queries_dir) end)
    :ok
  end

  describe "sample_table/2" do
    test "returns rows from table" do
      {:ok, rows} = Sampler.sample_table("users", limit: 5)
      assert length(rows) == 5
      assert is_map(hd(rows))
    end

    test "respects limit option" do
      {:ok, rows} = Sampler.sample_table("users", limit: 3)
      assert length(rows) == 3
    end
  end

  describe "export_table/3" do
    test "writes NDJSON output and returns row count" do
      output_path = Path.join(@test_queries_dir, "table_output.ndjson")

      {:ok, row_count} = Sampler.export_table("users", output_path, limit: 2)

      assert row_count == 2
      assert File.exists?(output_path)
      content = File.read!(output_path)
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == 2
    end
  end

  describe "query/2" do
    test "executes raw SQL query" do
      sql = "SELECT * FROM users LIMIT 2"
      {:ok, rows} = Sampler.query(sql)
      assert length(rows) == 2
    end

    test "respects timeout option" do
      sql = "SELECT * FROM users LIMIT 1"
      {:ok, _rows} = Sampler.query(sql, timeout: 5_000)
    end

    test "passes params to database" do
      # Mock adapter uses first param as limit when provided
      sql = "SELECT * FROM users LIMIT $1"
      {:ok, rows} = Sampler.query(sql, params: [7])
      assert length(rows) == 7
    end

    test "params override SQL LIMIT" do
      # Params take precedence over parsed SQL LIMIT
      sql = "SELECT * FROM users LIMIT 100"
      {:ok, rows} = Sampler.query(sql, params: [3])
      assert length(rows) == 3
    end
  end

  describe "query_file/2" do
    test "reads and evaluates EEx template" do
      path = Path.join(@test_queries_dir, "simple.sql.eex")

      File.write!(path, """
      SELECT * FROM users
      LIMIT 3
      """)

      {:ok, rows} = Sampler.query_file(path)
      assert length(rows) == 3
    end

    test "passes default assigns (@dev, @test, @prod, @date)" do
      path = Path.join(@test_queries_dir, "with_env.sql.eex")

      File.write!(path, """
      -- dev: <%= @dev %>, test: <%= @test %>, prod: <%= @prod %>
      SELECT * FROM users
      <%= if @test do %>
      LIMIT 2
      <% else %>
      LIMIT 10
      <% end %>
      """)

      {:ok, rows} = Sampler.query_file(path)
      # In test env, @test is true, so LIMIT 2
      assert length(rows) == 2
    end

    test "merges custom assigns" do
      path = Path.join(@test_queries_dir, "with_custom.sql.eex")

      File.write!(path, """
      SELECT * FROM users
      LIMIT <%= assigns[:limit] || 5 %>
      """)

      {:ok, rows} = Sampler.query_file(path, assigns: [limit: 4])
      assert length(rows) == 4
    end

    test "handles missing file" do
      result = Sampler.query_file("nonexistent.sql.eex")
      assert {:error, :enoent} = result
    end

    test "handles EEx syntax errors" do
      path = Path.join(@test_queries_dir, "bad_syntax.sql.eex")

      File.write!(path, """
      SELECT * FROM users
      <%= if @dev
      LIMIT 5
      """)

      assert_raise EEx.SyntaxError, fn ->
        Sampler.query_file(path)
      end
    end

    test "passes params to database" do
      path = Path.join(@test_queries_dir, "with_params.sql.eex")

      File.write!(path, """
      SELECT * FROM users WHERE status = $1 LIMIT $2
      """)

      # Mock adapter uses first param as limit
      {:ok, rows} = Sampler.query_file(path, params: [6])
      assert length(rows) == 6
    end
  end

  describe "export_query_file/3" do
    test "exports query results to NDJSON" do
      sql_path = Path.join(@test_queries_dir, "export.sql.eex")
      output_path = Path.join(@test_queries_dir, "output.ndjson")

      File.write!(sql_path, """
      SELECT * FROM users
      LIMIT 3
      """)

      assert {:ok, 3} = Sampler.export_query_file(sql_path, output_path)

      # Verify file exists and is valid NDJSON
      assert File.exists?(output_path)
      content = File.read!(output_path)
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == 3

      # Each line should be valid JSON
      Enum.each(lines, fn line ->
        assert {:ok, _} = Jason.decode(line)
      end)
    end

    test "encodes UUIDs correctly" do
      sql_path = Path.join(@test_queries_dir, "uuid_test.sql.eex")
      output_path = Path.join(@test_queries_dir, "uuid_output.ndjson")

      File.write!(sql_path, """
      SELECT * FROM users
      LIMIT 1
      """)

      {:ok, 1} = Sampler.export_query_file(sql_path, output_path)

      content = File.read!(output_path)
      {:ok, row} = Jason.decode(String.trim(content))

      # UUID should be a string (mock returns string UUIDs)
      assert is_binary(row["id"])
    end
  end

  # ===========================================================================
  # Streaming Tests
  # ===========================================================================

  describe "stream_table/3" do
    test "returns a stream of rows" do
      DbSampler.Database.with_stream(fn conn ->
        stream = Sampler.stream_table(conn, "users", limit: 5)
        assert is_function(stream) or is_struct(stream, Stream)
      end)
    end

    test "stream yields correct number of rows when consumed" do
      DbSampler.Database.with_stream(fn conn ->
        rows =
          conn
          |> Sampler.stream_table("users", limit: 4)
          |> Enum.to_list()

        assert length(rows) == 4
        assert is_map(hd(rows))
      end)
    end
  end

  describe "export_table_stream/3" do
    test "streams rows to NDJSON file" do
      output_path = Path.join(@test_queries_dir, "stream_output.ndjson")

      {:ok, row_count} = Sampler.export_table_stream("users", output_path, limit: 5)

      assert row_count == 5
      assert File.exists?(output_path)
      content = File.read!(output_path)
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == 5

      # Each line should be valid JSON
      Enum.each(lines, fn line ->
        assert {:ok, _} = Jason.decode(line)
      end)
    end

    test "produces same output as non-streaming export" do
      non_stream_path = Path.join(@test_queries_dir, "non_stream.ndjson")
      stream_path = Path.join(@test_queries_dir, "stream.ndjson")

      {:ok, 3} = Sampler.export_table("users", non_stream_path, limit: 3)
      {:ok, 3} = Sampler.export_table_stream("users", stream_path, limit: 3)

      non_stream_lines = non_stream_path |> File.read!() |> String.split("\n", trim: true)
      stream_lines = stream_path |> File.read!() |> String.split("\n", trim: true)

      assert length(non_stream_lines) == length(stream_lines)

      # Both should produce valid JSON with same keys
      Enum.zip(non_stream_lines, stream_lines)
      |> Enum.each(fn {ns, s} ->
        {:ok, ns_row} = Jason.decode(ns)
        {:ok, s_row} = Jason.decode(s)
        assert Map.keys(ns_row) == Map.keys(s_row)
      end)
    end
  end

  describe "export_query_file_stream/3" do
    test "streams SQL file results to NDJSON" do
      sql_path = Path.join(@test_queries_dir, "stream_query.sql.eex")
      output_path = Path.join(@test_queries_dir, "stream_query_output.ndjson")

      File.write!(sql_path, """
      SELECT * FROM users
      LIMIT 4
      """)

      {:ok, row_count} = Sampler.export_query_file_stream(sql_path, output_path)

      assert row_count == 4
      assert File.exists?(output_path)
      content = File.read!(output_path)
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == 4
    end

    test "handles missing file" do
      output_path = Path.join(@test_queries_dir, "missing_output.ndjson")
      result = Sampler.export_query_file_stream("nonexistent.sql.eex", output_path)
      assert {:error, :enoent} = result
    end
  end
end
