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
      |> assign(:my_name, nil)
      |> assign(:players, %{})
      |> assign(:game_round, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"game_id" => game_id}, _url, socket) do
    GameSupervisor.ensure_game_started(game_id)

    user_meta = %{
      guest_id: socket.assigns.my_guest_id,
      name: nil,
      online_at: DateTime.utc_now()
    }

    if connected?(socket) do
      SpyfallWeb.Endpoint.subscribe(topic(game_id))
      Presence.track(self(), topic(game_id), socket.assigns.my_guest_id, user_meta)
    end

    {
      :noreply,
      socket
      |> assign(:game_id, game_id)
      |> assign(:page_title, "Spyfall Game: " <> game_id)
      |> assign(:players, online_players(topic(game_id)))
      |> assign(:game_round, client_visible(Game.round(game_id), socket.assigns.my_guest_id))
    }
  end

  defp online_players(topic) do
    Presence.list(topic)
    |> Enum.map(fn {_guest_id, %{metas: [meta | _]}} -> meta end)
    |> Enum.sort(fn %{online_at: a}, %{online_at: b} -> DateTime.compare(a, b) == :lt end)
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: payload, topic: topic}, socket) do
    Logger.info("presence_diff, #{inspect(payload)}")

    {:noreply, assign(socket, :players, online_players(topic))}
  end

  def handle_info(%{event: "round_started", payload: %{round: round}}, socket) do
    {:noreply, assign(socket, :game_round, client_visible(round, socket.assigns.my_guest_id))}
  end

  def handle_info(%{event: "round_ended"}, socket) do
    {:noreply, assign(socket, :game_round, nil)}
  end

  defp client_visible(nil, _), do: nil

  defp client_visible(round, guest_id) do
    player_specific =
      case round.player_roles[guest_id] do
        :spy ->
          %{
            role: :spy
          }

        :player ->
          %{
            role: :player,
            location: round.location
          }

        nil ->
          %{role: :joined_late}
      end

    Map.take(round, [:version, :started_at])
    |> Map.merge(player_specific)
  end

  @impl true
  def handle_event("start_round", _value, socket) do
    Game.start_round(
      socket.assigns.game_id,
      Enum.map(socket.assigns.players, &Map.get(&1, :guest_id))
    )

    {:noreply, socket}
  end

  def handle_event("end_round", _value, socket) do
    Game.end_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  def handle_event("update_name", %{"name" => name}, socket) do
    Presence.update(
      self(),
      topic(socket.assigns.game_id),
      socket.assigns.my_guest_id,
      &Map.put(&1, :name, name)
    )

    {:noreply, assign(socket, :my_name, name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Spyfall Game: {@game_id}</h1>
    <p>Share this page's URL with your friends to have them join the game!</p>

    <%= if @my_name do %>
      <h2 id="greeting">Welcome, {@my_name}!</h2>
    <% else %>
      <h2 id="greeting">Welcome, guest! I'll call you {@my_guest_id}</h2>
    <% end %>

    <form phx-change="update_name" phx-debounce="300">
      <input
        type="text"
        name="name"
        value={@my_name}
        placeholder="Enter your name"
        id="name-input"
        phx-hook="NamePersister"
      />
    </form>

    <h2>Players Online ({length(@players)}):</h2>
    <ul id="player-list">
      <li :for={player_meta <- @players}>
        {player_meta.name || "Guest " <> player_meta.guest_id} (joined at {Calendar.strftime(
          player_meta.online_at,
          "%H:%M:%S"
        )})
      </li>
    </ul>

    <hr />

    <%= if @game_round do %>
      <h3>Round in Progress!</h3>
      <div class="my-role">
        <h4>Your Role:</h4>
        <%= case @game_round.role do %>
          <% :spy -> %>
            <p>You are the <strong>Spy!</strong></p>
            <p>Try to figure out the location without revealing you're the spy.</p>
          <% :player -> %>
            <p>Location: <strong>{@game_round.location}</strong></p>
            <p>You are a regular player. Try to identify the spy.</p>
          <% :joined_late -> %>
            <p>You're not in this round</p>
            <p>Wait for the next game round to start. They're usually not long.</p>
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
      <%= if length(@players) >= 3 do %>
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

  defp topic(game_id), do: "spyfall:game:" <> game_id
end
