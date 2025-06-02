defmodule Spyfall.GameSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Ensures a Game GenServer is started for the given game_id and returns its pid.
  Starts it if it's not already running.
  """
  def ensure_game_started(game_id) do
    case Registry.lookup(Spyfall.Registry, game_id) do
      [{pid, _value}] ->
        # Already started
        pid

      [] ->
        # Not found, so start it
        case DynamicSupervisor.start_child(__MODULE__, {Spyfall.Game, game_id: game_id}) do
          {:ok, pid} ->
            Logger.info("[Supervisor] Started Game #{game_id}.")
            pid

          {:ok, pid, _child_info} ->
            Logger.info("[Supervisor] Started Game #{game_id}.")
            pid

          {:error, {:already_started, pid}} ->
            Logger.warning("[Supervisor] Race condition: Game #{game_id} was already started.")
            pid

          {:error, reason} ->
            Logger.error("[Supervisor] Failed to start Game #{game_id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  @doc """
  Terminate a Game GenServer
  """
  def stop_game(game_id) do
    case Registry.lookup(Spyfall.Registry, game_id) do
      [{pid, _value}] ->
        Logger.info("[Supervisor] Terminated Game #{game_id} with pid #{inspect(pid)}.")
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        :ok

      [] ->
        :ok
    end
  end
end
