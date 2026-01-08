# DbSampler

[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://dweinstein.github.io/db_sampler/)

Sample rows from a PostgreSQL database and export to NDJSON.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [{:db_sampler, git: "https://github.com/dweinstein/db_sampler.git"}]
end
```

Set your database URL:

```bash
export DATABASE_URL="postgresql://user:password@localhost:5432/mydb"
```

## Usage

### Sample from a table

```bash
mix sample --table users --limit 100
mix sample -t orders -l 500 -o orders.ndjson
mix sample --table products --order "created_at DESC"
```

### Execute SQL from a template file

```bash
mix sample --sql examples/queries/users_sample.sql.eex
mix sample --sql examples/queries/users_sample.sql.eex --var limit=100
```

### Options

| Flag | Short | Description |
|------|-------|-------------|
| `--table` | `-t` | Table to sample (required in table mode) |
| `--sql` | `-s` | Path to `.sql.eex` file (SQL mode) |
| `--limit` | `-l` | Number of rows (default: 100) |
| `--output` | `-o` | Output file (default: sample.ndjson) |
| `--order` | `-r` | ORDER BY clause |
| `--timeout` | | Query timeout in ms (default: 60000) |
| `--var` | | Pass variable to template (repeatable) |

## SQL Templates

SQL files use EEx templating. Built-in variables:

- `@dev`, `@test`, `@prod` - environment flags
- `@date` - current UTC date
- `assigns[:var]` - custom variables via `--var`

Example:

```sql
SELECT * FROM users
ORDER BY created_at DESC
<%= if @dev do %>
LIMIT <%= assigns[:limit] || 100 %>
<% end %>
```

## Programmatic API

```elixir
{:ok, rows} = DbSampler.sample_table("users", limit: 100)
{:ok, count} = DbSampler.export_table("users", "output.ndjson")
{:ok, rows} = DbSampler.query_file("queries/report.sql.eex", assigns: [limit: 50])
```

See `mix docs` for full API documentation.

## Security

This tool executes SQL queries directly against your database. SQL template
files (`.sql.eex`) can contain arbitrary Elixir code via EEx.

**This tool is intended for use by trusted developers and operators who
already have database access.** Do not expose the `--sql` or `--var` flags
to untrusted input.
