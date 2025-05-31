defmodule SpyfallWeb.GameController do
  use SpyfallWeb, :controller

  def create(conn, _params) do
    redirect(conn, to: ~p"/games/#{generate_unique_game_id()}")
  end

  defp generate_unique_game_id() do
    Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false)
  end
end
