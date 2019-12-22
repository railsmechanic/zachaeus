if Code.ensure_loaded?(Plug) do
  defmodule Zachaeus.Plug do
    @moduledoc """
    Provides functions and the behaviour for dealing with Zachaeus in a Plug environment.
    You can use the functions to implement plugs with a custom behaviour.
    To fullfill the behaviour, you need to implement the `respond` behaviour within your custom plug.

    The usual functions you'd use in your plug are:

    ### `fetch_license(conn)`
    Try to get a signed license passed from the HTTP authorization request header.

    ```elixir
    {:ok, "lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc..."} = Zachaeus.Plug.fetch_license(conn)
    ```

    ### `verify_license(signed_license, conn)`
    Verifies a signed license with the `public_key` stored in your configuration environment.

    ```elixir
    {{:ok, %License{}}, conn} = Zachaeus.Plug.verify_license(signed_license, conn)
    ```

    ### `validate_license({signed_license, conn})`
    Validates an already verified license whether it is still valid.

    ```elixir
    {{:ok, %License{}}, conn} = Zachaeus.Plug.validate_license({signed_license, conn})
    ```
    """
    alias Zachaeus.{License, Error}
    import Plug.Conn

    ## -- PLUG MACROS
    defmacro __using__(_opts) do
      quote do
        alias Zachaeus.{License, Error}
        import Zachaeus.Plug
        import Plug.Conn

        @behaviour Plug
        @behaviour Zachaeus.Plug
      end
    end

    ## -- PLUG BEHAVIOUR
    @doc """
    Respond if the license is still valid or has already expired.
    This callback is meant to implement your own logic, e.g. rendering a template, returning some JSON or just aplain text.

    ## Example
        conn = Zachaeus.Plug.respond_to_license({{:ok, %License{}}, conn})
    """
    @callback respond_to_license({{:ok, License.t()} | {:error, Error.t()}, Plug.Conn.t()}) :: Plug.Conn.t()

    ## -- PLUG FUNCTIONS
    @doc """
    Fetches a signed license which is passed via the `Authorization` HTTP request header as a Bearer Token.
    When no valid signed license is found, the function returns an corresponding error.

    ## HTTP header example
        Authorization: lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...

    ## Example
        {{:ok, "lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc..."}, conn} = Zachaeus.Plug.fetch_license(conn)
    """
    @spec fetch_license(Plug.Conn.t()) :: {{:ok, License.signed()} | {:error, Error.t()}, Plug.Conn.t()}
    def fetch_license(conn) do
      case get_req_header(conn, "Authorization") do
        ["Bearer " <> signed_license | _] when is_binary(signed_license) and byte_size(signed_license) > 0 ->
          {{:ok, signed_license}, conn}
        _license_not_found_in_request ->
          {{:error, %Error{code: :extraction_failed, message: "Unable to extract license from the HTTP Authorization request header"}}, conn}
      end
    end

    @doc """
    Verifies a signed license whether it is valid and not tampered.
    When no signed license could be retrieved by `fetch_license` it forwards this error.

    ## Example
        {{:ok, %License{...}}, conn} = Zachaeus.Plug.verify_license({{:ok, "lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc..."}, conn})
    """
    @spec verify_license({{:ok, License.signed()} | {:error, Error.t()}, Plug.Conn.t()}) :: {{:ok, License.t()} | {:error, Error.t()}, Plug.Conn.t()}
    def verify_license({{:ok, signed_license}, conn}) do
      case Zachaeus.verify(signed_license) do
        {:ok, %License{identifier: identifier, plan: plan}} = license ->
          conn =
            conn
            |> put_private(:zachaeus_identifier, identifier)
            |> put_private(:zachaeus_plan, plan)

          {license, conn}
        {:error, %Error{}} = error ->
          {error, conn}
        _unknown_error ->
          {{:error, %Error{code: :verification_failed, message: "Unable to verify the license to to an unknown error"}}, conn}
      end
    end
    def verify_license({{:error, %Error{}} = error, conn}),
      do: {error, conn}
    def verify_license(_invalid_license_or_error, conn),
      do: {{:error, %Error{code: :verification_failed, message: "Unable to verify the license due to an invalid type"}}, conn}

    @doc """
    Validates a license whether it is not expired.
    When the license could not be verified by `verify_license` it forwards this error.

    ## Example
        {{:ok, %License{...}, conn} = Zachaeus.Plug.validate_license({{:ok, %License{}}, conn})
    """
    @spec validate_license({{:ok, License.t()} | {:error, Error.t()}, Plug.Conn.t()}) :: {{:ok, License.t()} | {:error, Error.t()}, Plug.Conn.t()}
    def validate_license({{:ok, license}, conn}) do
      case Zachaeus.validate(license) do
        {:ok, remaining_seconds} ->
          conn =
            conn
            |> put_private(:zachaeus_remaining_seconds, remaining_seconds)

          {license, conn}
        {:error, %Error{}} = error ->
          {error, conn}
        _unknown_error ->
          {{:error, %Error{code: :validation_failed, message: "Unable to validate license due to an unknown error"}}, conn}
      end
    end
    def validate_license({{:error, %Error{}} = error, conn}),
      do: {error, conn}
    def validate_license(_invalid_license_or_error, conn),
      do: {{:error, %Error{code: :validation_failed, message: "Unable to validate license due to an invalid type"}}, conn}
  end
end
