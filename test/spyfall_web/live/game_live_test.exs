defmodule SpyfallWeb.GameLiveTest do
  use SpyfallWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GameLive Presence" do
    test "two users joining the same game see each other", %{conn: conn_user1} do
      game_id = "test-game-" <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false)

      # --- User 1 connects ---
      {:ok, view_user1, html_user1} = live(conn_user1, ~p"/games/#{game_id}")

      # Extract User 1's guest ID from their view
      # Assuming your HTML includes: <p>Your Guest ID: guest:xxxx</p>
      assert html_user1 =~ "Welcome, Guest", "No welcome message in initial HTML for User 1"
      assert html_user1 =~ "Players Online (1)", "Presence should list one online for user 1"

      [guest_id_user1] =
        Regex.run(~r/Welcome, Guest (guest:\w+)!/, html_user1, capture: :all_but_first)

      refute is_nil(guest_id_user1), "Failed to extract User 1's guest ID. HTML: #{html_user1}"
      assert online_players(view_user1) == [guest_id_user1]

      # --- User 2 connects ---
      conn_user2 = Phoenix.ConnTest.build_conn()

      {:ok, view_user2, html_user2} = live(conn_user2, ~p"/games/#{game_id}")

      assert html_user2 =~ "Welcome, Guest", "No welcome message in initial HTML for User 2"
      assert html_user2 =~ "Players Online (2)", "Presence should list two online for user 2"

      [guest_id_user2] =
        Regex.run(~r/Welcome, Guest (guest:\w+)!/, html_user2, capture: :all_but_first)

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

    Regex.scan(~r/guest:\w+/, html_fragment)
    |> List.flatten()
    |> Enum.sort()
  end
end
