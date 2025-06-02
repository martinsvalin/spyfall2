defmodule Spyfall.Game do
  use GenServer
  alias Spyfall.GameData
  require Logger

  def start_link(opts \\ []) do
    game_id = Keyword.fetch!(opts, :game_id)

    GenServer.start_link(__MODULE__, opts, name: via(game_id))
  end

  defp via(game_id), do: {:via, Registry, {Spyfall.Registry, game_id}}

  @type role :: :spy | :player
  @type round :: %{
          started_at: DateTime.t(),
          version: :original | :spyfall2,
          location: String.t(),
          player_roles: %{String.t() => role()}
        }
  @type t :: %{
          game_id: String.t(),
          topic: String.t(),
          round: round() | nil
        }

  @enforce_keys [:game_id, :topic]
  defstruct [:game_id, :topic, :round]

  @spec new(String.t()) :: t()
  def new(game_id) do
    %__MODULE__{
      game_id: game_id,
      topic: "spyfall:game:" <> game_id,
      round: nil
    }
  end

  # --- Client API ---

  @doc """
  Starts a new round of Spyfall for the given game_id with the provided player_ids.
  Broadcasts the outcome. player_ids should be a list of guest_ids.
  """
  def start_round(game_id, player_ids, version \\ :original) do
    GenServer.call(via(game_id), {:start_round, player_ids, version})
  end

  def end_round(game_id) do
    GenServer.call(via(game_id), :end_round)
  end

  def round(game_id) do
    GenServer.call(via(game_id), :get_round)
  end

  @doc """
  Gets the role and location information for a specific player in a game.
  """
  def get_player_info(game_id_or_pid, player_id) do
    GenServer.call(game_id_or_pid, {:get_player_info, player_id})
  end

  #  --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    game = new(game_id)
    SpyfallWeb.Endpoint.subscribe(game.topic)

    Logger.info("[Game #{game_id}] GenServer starting.")
    {:ok, game}
  end

  @impl true
  def handle_call({:start_round, player_ids, version}, _from, state) do
    if state.round do
      {:reply, {:error, :round_already_active}, state}
    else
      location = Enum.random(GameData.locations(version))
      spy_id = Enum.random(player_ids)

      player_roles =
        Map.new(player_ids, fn
          ^spy_id -> {spy_id, :spy}
          player_id -> {player_id, :player}
        end)

      round = %{
        started_at: DateTime.utc_now(),
        version: version,
        location: location,
        player_roles: player_roles
      }

      Logger.info("[Game #{state.game_id}] New round. Location: #{location}, Spy: #{spy_id}")

      SpyfallWeb.Endpoint.broadcast(state.topic, "round_started", %{
        round: round
      })

      {:reply, :ok, %{state | round: round}}
    end
  end

  def handle_call(:end_round, _from, state) do
    Logger.info("[Game #{state.game_id}] Round ended.")

    SpyfallWeb.Endpoint.broadcast(state.topic, "round_ended", %{})
    {:reply, :ok, %{state | round: nil}}
  end

  def handle_call(:get_round, _from, state) do
    {:reply, state.round, state}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, state) do
    case SpyfallWeb.Presence.list(state.topic) do
      map when map_size(map) == 0 ->
        Logger.info("[Game #{state.game_id}] Everybody left, we should shut down the game server")
        Spyfall.GameSupervisor.stop_game(state.game_id)

      _ ->
        {:noreply, state}
    end
  end

  # only live views need to handle these messages
  def handle_info(%{event: "round_started"}, state), do: {:noreply, state}
  def handle_info(%{event: "round_ended"}, state), do: {:noreply, state}
end
