defmodule Spyfall.GameSupervisorTest do
  alias Spyfall.GameSupervisor
  use ExUnit.Case

  @game_id "GameSupervisor"

  test "starting and stopping a Game genserver" do
    before = DynamicSupervisor.count_children(GameSupervisor).active

    # Start 1 child
    GameSupervisor.ensure_game_started(@game_id)
    assert count_active() == before + 1

    # Can safely be called multiple times
    GameSupervisor.ensure_game_started(@game_id)
    assert count_active() == before + 1

    # Genserver process can be found via the Registry
    [{pid, _}] = Registry.lookup(Spyfall.Registry, @game_id)
    assert is_pid(pid)

    # Stopping the Game genserver
    :ok = GameSupervisor.stop_game(@game_id)
    assert count_active() == before
  end

  defp count_active() do
    DynamicSupervisor.count_children(GameSupervisor).active
  end
end
