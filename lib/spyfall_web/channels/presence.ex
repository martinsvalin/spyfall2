defmodule SpyfallWeb.Presence do
  use Phoenix.Presence,
    otp_app: :spyfall,
    pubsub_server: Spyfall.PubSub
end
