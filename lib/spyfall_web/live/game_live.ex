defmodule SpyfallWeb.GameLive do
  use SpyfallWeb, :live_view
  require Logger

  alias SpyfallWeb.Presence
  alias Spyfall.{Game, GameData, GameSupervisor}

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Spyfall Game")
      |> assign(:game_id, nil)
      |> assign(:my_guest_id, session["guest_id"])
      |> assign(:players, %{})
      |> assign(:game_round, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"game_id" => game_id}, _url, socket) do
    GameSupervisor.ensure_game_started(game_id)

    game_topic = "spyfall:game:" <> game_id

    user_meta = %{
      guest_id: socket.assigns.my_guest_id,
      online_at: DateTime.utc_now()
    }

    if connected?(socket) do
      SpyfallWeb.Endpoint.subscribe(game_topic)
      Presence.track(self(), game_topic, socket.assigns.my_guest_id, user_meta)
    end

    {
      :noreply,
      socket
      |> assign(:game_id, game_id)
      |> assign(:page_title, "Spyfall Game: " <> game_id)
      |> assign(:players, online_players(game_topic))
      |> assign(:game_round, client_visible(Game.round(game_id), socket.assigns.my_guest_id))
    }
  end

  defp online_players(game_topic) do
    Presence.list(game_topic)
    |> presences_to_players()
  end

  defp presences_to_players(precenses) do
    # Note: presences, such as from Phoenix.Presence.list, contain a map where keys
    # are the tracked IDs (our guest_ids) and values are maps containing a :metas key
    # with a list of metadata entries.
    # Each guest_id has one meta entry, so we can simplify.
    Map.new(precenses, fn {guest_id, %{metas: [meta | _]}} -> {guest_id, meta} end)
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: payload, topic: _topic}, socket) do
    updated_players =
      socket.assigns.players
      |> Map.merge(presences_to_players(payload.joins))
      |> Map.drop(Map.keys(payload.leaves))

    {:noreply, assign(socket, :players, updated_players)}
  end

  def handle_info(%{event: "round_started", payload: %{round: round}}, socket) do
    {:noreply, assign(socket, :game_round, client_visible(round, socket.assigns.my_guest_id))}
  end

  def handle_info(%{event: "round_ended"}, socket) do
    {:noreply, assign(socket, :game_round, nil)}
  end

  defp client_visible(nil, _), do: nil

  defp client_visible(round, guest_id) do
    case round.player_roles[guest_id] do
      :spy ->
        %{
          role: :spy,
          version: round.version
        }

      :player ->
        %{
          role: :player,
          location: round.location,
          version: round.version
        }
    end
  end

  @impl true
  def handle_event("start_round", _value, socket) do
    Game.start_round(socket.assigns.game_id, Map.keys(socket.assigns.players))
    {:noreply, socket}
  end

  def handle_event("end_round", _value, socket) do
    Game.end_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Spyfall Game: {@game_id}</h1>
    <p>Welcome, Guest {@my_guest_id}!</p>
    <p>Share this page's URL with your friends to have them join the game!</p>

    <h2>Players Online ({map_size(@players)}):</h2>
    <ul id="player-list">
      <li :for={{guest_id, player_meta} <- @players}>
        Guest {guest_id} (joined at {player_meta.online_at})
      </li>
    </ul>

    <hr />

    <%= if @game_round do %>
      <h3>Round in Progress!</h3>
      <div class="my-role">
        <h4>Your Role:</h4>
        <%= if @game_round.role == :spy do %>
          <p>You are the <strong>Spy!</strong></p>
          <p>Try to figure out the location without revealing you're the spy.</p>
        <% else %>
          <p>Location: <strong>{@game_round.location}</strong></p>
          <p>You are a regular player. Try to identify the spy.</p>
        <% end %>
      </div>

      <button phx-click="end_round" class="button">End Round</button>

      <h3>All Possible Locations (for reference):</h3>
      <ul class="locations-list">
        <li :for={loc <- GameData.locations(@game_round.version)}>{loc}</li>
      </ul>
    <% else %>
      <h3>Waiting to Start Round</h3>
      <p>Gather your friends! When ready, someone can deal the cards.</p>
      <%= if map_size(@players) >= 3 do %>
        <button phx-click="start_round" class="button">Deal Cards & Start Round</button>
      <% else %>
        <p>Need at least 3 players to start.</p>
        <button class="button-disabled" disabled>Deal Cards & Start Round</button>
      <% end %>
    <% end %>

    <hr />

    <p><.link href={~p"/"}>Back to Lobby</.link></p>
    """
  end
end
