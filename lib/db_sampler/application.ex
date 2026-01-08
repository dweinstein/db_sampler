defmodule DbSampler.Application do
  @moduledoc false

  use Application

  alias DbSampler.Config

  @impl true
  def start(_type, _args) do
    children = build_children()

    opts = [strategy: :one_for_one, name: DbSampler.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp build_children do
    if Mix.env() == :test do
      []
    else
      [{Postgrex, postgrex_opts()}]
    end
  end

  defp postgrex_opts do
    uri = URI.parse(Config.database_url())
    [username, password] = String.split(uri.userinfo, ":")

    [
      name: Config.database_conn(),
      hostname: uri.host,
      port: uri.port,
      database: String.trim_leading(uri.path, "/"),
      username: username,
      password: password
    ]
  end
end
