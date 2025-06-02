defmodule Spyfall.GameTest do
  use ExUnit.Case
  alias Spyfall.Game

  @game_id "GameTest"
  @players ~w(Huey Dewey Louie)

  setup_all do
    Game.start_link(game_id: @game_id)
    :ok
  end

  test "can start and end a round" do
    Game.start_round(@game_id, @players)
    Game.end_round(@game_id)
  end

  describe "round" do
    test "initially empty" do
      assert Game.round(@game_id) == nil
    end

    test "returns the state of a game round after it is started" do
      Game.start_round(@game_id, @players)
      round = Game.round(@game_id)

      assert %DateTime{} = round.started_at
      assert round.version == :original
      assert round.location

      # All players are assigned a role. There is exactly one spy
      assert Enum.sort(Map.keys(round.player_roles)) == Enum.sort(@players)
      assert Enum.sort(Map.values(round.player_roles)) == [:player, :player, :spy]

      Game.end_round(@game_id)
    end
  end
end
