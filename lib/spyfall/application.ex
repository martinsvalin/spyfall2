defmodule Spyfall.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      SpyfallWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:spyfall, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Spyfall.PubSub},
      SpyfallWeb.Presence,
      Spyfall.Registry,
      Spyfall.GameSupervisor,
      SpyfallWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Spyfall.Supervisor]

    Supervisor.start_link(children, opts)
    |> tap(&Logger.info("Spyfall application started", result: &1))
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SpyfallWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
