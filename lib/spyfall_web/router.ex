defmodule SpyfallWeb.Router do
  use SpyfallWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug SpyfallWeb.Plugs.EnsureGuestId
    plug :fetch_live_flash
    plug :put_root_layout, html: {SpyfallWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", SpyfallWeb do
    pipe_through :browser

    get "/", PageController, :home
    post "/games", GameController, :create

    live "/games/:game_id", GameLive
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:spyfall, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SpyfallWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
