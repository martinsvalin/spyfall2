defmodule SpyfallWeb.GameLiveTest do
  use SpyfallWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GameLive Presence" do
    test "two users joining the same game see each other", %{conn: conn_user1} do
      game_id = random_game_id()

      # --- User 1 connects ---
      {:ok, view_user1, html_user1} = live(conn_user1, ~p"/games/#{game_id}")

      # Extract User 1's guest ID from their view
      # Assuming your HTML includes: <p>Your Guest ID: guest:xxxx</p>
      assert html_user1 =~ "Welcome, guest", "No welcome message in initial HTML for User 1"
      assert html_user1 =~ "Players Online (1)", "Presence should list one online for user 1"

      greeting_user1 = element(view_user1, "#greeting") |> render()
      assert greeting_user1 =~ ~r/guest:[\w-]+/
      [guest_id_user1] = Regex.run(~r/guest:[\w-]+/, greeting_user1)

      refute is_nil(guest_id_user1), "Failed to extract User 1's guest ID. HTML: #{html_user1}"
      assert online_players(view_user1) == [guest_id_user1]

      # --- User 2 connects ---
      conn_user2 = Phoenix.ConnTest.build_conn()

      {:ok, view_user2, html_user2} = live(conn_user2, ~p"/games/#{game_id}")

      assert html_user2 =~ "Welcome, guest", "No welcome message in initial HTML for User 2"
      assert html_user2 =~ "Players Online (2)", "Presence should list two online for user 2"

      greeting_user2 = element(view_user2, "#greeting") |> render()
      assert greeting_user2 =~ ~r/guest:[\w-]+/
      [guest_id_user2] = Regex.run(~r/guest:[\w-]+/, greeting_user2)

      refute is_nil(guest_id_user2), "Failed to extract User 2's guest ID. HTML: #{html_user2}"
      assert guest_id_user1 != guest_id_user2
      assert online_players(view_user2) == Enum.sort([guest_id_user1, guest_id_user2])

      # --- Verify User 1's view has updated ---
      assert online_players(view_user1) == Enum.sort([guest_id_user1, guest_id_user2])
      html_user1 = render(view_user1)
      assert html_user1 =~ "Players Online (2)"

      # Optional: Test a user leaving
      # Simulate user 2 disconnecting
      GenServer.stop(view_user2.pid)

      # Wait for user 1's view to receive presence diff
      Process.sleep(10)
      assert online_players(view_user1) == [guest_id_user1]
      render(view_user1) =~ "Players Online (1)"
    end
  end

  defp online_players(view) do
    html_fragment = element(view, "#player-list") |> render()

    Regex.scan(~r/guest:[\w-]+/, html_fragment)
    |> List.flatten()
    |> Enum.sort()
  end

  describe "A game round" do
    test "three users join, start a game round, then ends it", %{conn: conn_user1} do
      game_id = random_game_id()
      conn_user2 = Phoenix.ConnTest.build_conn()
      conn_user3 = Phoenix.ConnTest.build_conn()

      {:ok, view_user1, _html_user1} = live(conn_user1, ~p"/games/#{game_id}")
      {:ok, view_user2, _html_user2} = live(conn_user2, ~p"/games/#{game_id}")

      # Start round button is disabled until at least three players are online
      assert element(view_user1, ".button-disabled") |> render() =~ ~s(disabled="disabled")

      {:ok, view_user3, _html_user3} = live(conn_user3, ~p"/games/#{game_id}")

      # All users see each other
      assert length(online_players(view_user1)) == 3
      assert length(online_players(view_user2)) == 3
      assert length(online_players(view_user3)) == 3
      assert element(view_user1, "h3", "Waiting to Start Round") |> render()

      # A player can start a game round
      button = element(view_user1, ".button")
      assert render(button) =~ "Deal Cards"
      render_click(button)
      assert element(view_user1, "h3", "Round in Progress!") |> render()

      # one player is the spy, two players see the location
      [{spy, 1}, {_location, 2}] =
        [
          element(view_user1, ".my-role strong"),
          element(view_user2, ".my-role strong"),
          element(view_user3, ".my-role strong")
        ]
        |> Enum.map(&render/1)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_, v} -> v end)

      assert spy =~ "Spy!"

      # a player can end the game round
      button = element(view_user1, ".button")
      assert render(button) =~ "End Round"
      render_click(button)
      assert element(view_user1, "h3", "Waiting to Start Round") |> render()
    end
  end

  defp random_game_id() do
    "test-game-" <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false)
  end
end
