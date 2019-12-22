if Code.ensure_loaded?(Plug) do
  defmodule Zachaeus.Plug.EnsureAuthenticated do
    @moduledoc """
    This plug ensures that a valid token was provided and has been verified on the request.

      If one is not found, the `auth_error` will be called with `:unauthenticated`

    This, like all other Guardian plugs, requires a Guardian pipeline to be setup.
    It requires an implementation module, an error handler and a key.
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
