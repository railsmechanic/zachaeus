if Code.ensure_loaded?(Plug) do
  defmodule Zachaeus.Plug.EnsureAuthenticated do
    @moduledoc """
    This plug ensures that a valid and unexpired license was provided on the request.
    If the license could not be found, has expired or is just invalid, it returns a JSON error representation.
    You can use this plug in your own application e.g. within the authentication pipeline.

    For example:
      defmodule MyAppWeb.Router do
        use Phoenix.Router

        pipeline :api do
          plug :accepts, ["json"]
          plug Zachaeus.Plug.EnsureAuthenticated
        end

        scope "/" do
          pipe_through :api
          # API related routes...
        end
      end
    """
    use Zachaeus.Plug

    def init(opts), do: opts

    def call(conn, _opts) do
      conn
      |> fetch_license()
      |> verify_license()
      |> validate_license()
      |> respond_to_license()
    end

    def respond_to_license({{:ok, _license}, conn}), do: conn
    def respond_to_license({{:error, %Error{message: reason}}, conn}) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(:unauthorized, "{error: #{reason}}")
      |> halt()
    end
  end
end
