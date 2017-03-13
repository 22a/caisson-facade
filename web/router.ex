defmodule Facade.Router do
  use Facade.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug Plug.Parsers, parsers: [:urlencoded]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Facade do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    post "/execute", PageController, :execute
  end

  # Other scopes may use custom stacks.
  # scope "/api", Facade do
  #   pipe_through :api
  # end
end
