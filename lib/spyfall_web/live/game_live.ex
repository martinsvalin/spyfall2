defmodule SpyfallWeb.GameLive do
  use SpyfallWeb, :live_view

  alias SpyfallWeb.Presence

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Spyfall Game")
      |> assign(:game_id, nil)
      |> assign(:current_guest_id, session["guest_id"])
      |> assign(:players, %{})

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"game_id" => game_id}, _url, socket) do
    game_topic = "spyfall:game:" <> game_id

    user_meta = %{
      guest_id: socket.assigns.current_guest_id,
      online_at: inspect(System.system_time(:second))
    }

    if connected?(socket) do
      SpyfallWeb.Endpoint.subscribe(game_topic)
      Presence.track(self(), game_topic, socket.assigns.current_guest_id, user_meta)
    end

    # Fetch the current list of presences for this topic
    # Note: Phoenix.Presence.list returns a map where keys are the tracked IDs (our guest_ids)
    # and values are maps containing a :metas key with a list of metadata entries.
    # For a simple setup where each guest_id has one meta entry, we can simplify.
    present_players =
      Presence.list(game_topic)
      |> presences_to_players()

    socket =
      socket
      |> assign(:game_id, game_id)
      |> assign(:page_title, "Spyfall Game: " <> game_id)
      # Update the list of players
      |> assign(:players, present_players)

    {:noreply, socket}
  end

  defp presences_to_players(precenses) do
    Map.new(precenses, fn {id, %{metas: [meta | _]}} -> {id, meta} end)
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: payload, topic: _topic}, socket) do
    updated_players =
      socket.assigns.players
      |> Map.merge(presences_to_players(payload.joins))
      |> Map.drop(Map.keys(payload.leaves))

    {:noreply, assign(socket, :players, updated_players)}
  end

  # Fallback for other messages (optional, good for debugging)
  def handle_info(msg, socket) do
    IO.inspect(msg, label: "GameLive received unhandled info")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Spyfall Game: {@game_id}</h1>
    <p>Welcome, Guest {@current_guest_id}!</p>
    <p>Share this page's URL with your friends to have them join the game!</p>

    <h2>Players Online ({map_size(@players)}):</h2>
    <ul id="player-list">
      <li :for={{_guest_id, player_meta} <- @players}>
        Guest {player_meta.guest_id} (joined at {player_meta.online_at})
      </li>
    </ul>

    <p><.link href={~p"/"}>Back to Lobby</.link></p>
    """
  end
end
