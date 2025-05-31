defmodule SpyfallWeb.Plugs.EnsureGuestId do
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :guest_id) do
      existing_guest_id when is_binary(existing_guest_id) ->
        conn

      nil ->
        new_guest_id = "guest:" <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false)
        put_session(conn, :guest_id, new_guest_id)
    end
  end
end
