if Code.ensure_loaded?(Plug) do
  defmodule Zachaeus.Plug do
    @moduledoc """
    Provides functions and a behaviour for dealing with Zachaeus in a Plug environment.
    You can use the following functions to build plugs with your own behaviour.
    To fulfill the behaviour, the `build_response` callback needs to be implemented within your custom plug.

    The usual functions you would use in your plug are:

    ### `fetch_license(conn)`
    Try to get a signed license passed from the HTTP authorization request header.
    When an error occurs, the error is forwarded, in order to be handled within the `build_response` function.

    ```elixir
    {:ok, "lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc..."} = Zachaeus.Plug.fetch_license(conn)
    ```

    ### `verify_license({conn, signed_license})`
    Verifies a signed license with the `public_key` stored in your configuration environment.
    When an error occurs, the error is forwarded, in order to be handled within the `build_response` function.

    ```elixir
    {conn, {:ok, %License{}}} = Zachaeus.Plug.verify_license({conn, {:ok, "lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc..."}})
    ```

    ### `validate_license({conn, license})`
    Validates an already verified license whether it is still valid.
    When an error occurs, the error is forwarded, in order to be handled within the `build_response` function.

    ```elixir
    {conn, {:ok, %License{...}}} = Zachaeus.Plug.validate_license({conn, {:ok, %License{...}}})
    ```
    """
    alias Zachaeus.{License, Error}
    import Plug.Conn

    ## -- PLUG MACRO
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
    Respond whether the license is still valid or has already expired.
    This callback is meant to implement your own logic, e.g. rendering a template, returning some JSON or just aplain text.

    ## Example
        conn = Zachaeus.Plug.build_response({conn, {:ok, %License{...}}})
    """
    @callback build_response({Plug.Conn.t(), {:ok, License.t()} | {:error, Error.t()}}) :: Plug.Conn.t()

    ## -- PLUG FUNCTIONS
    @doc """
    Fetches a signed license which is passed via the `Authorization` HTTP request header as a Bearer Token.
    When no valid signed license is found, the function returns a corresponding error.

    ## HTTP header example
        Authorization: lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...

    ## Example
        {conn, {:ok, "lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc..."}} = Zachaeus.Plug.fetch_license(conn)
    """
    @spec fetch_license(Plug.Conn.t()) :: {Plug.Conn.t(), {:ok, License.signed()} | {:error, Error.t()}}
    def fetch_license(conn) do
      case get_req_header(conn, "authorization") do
        ["Bearer " <> signed_license | _] when is_binary(signed_license) and byte_size(signed_license) > 0 ->
          {conn, {:ok, signed_license}}
        _license_not_found_in_request ->
          {conn, {:error, %Error{code: :extraction_failed, message: "Unable to extract license from the HTTP Authorization request header"}}}
      end
    end

    @doc """
    Verifies that a signed license is valid and has not been tampered.
    When no signed license could be retrieved by the `fetch_license` function, it forwards this error.

    ## Example
        {conn, {:ok, %License{}}} = Zachaeus.Plug.verify_license({conn, {:ok, "lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc..."}})
    """
    @spec verify_license({Plug.Conn.t(), {:ok, License.signed()} | {:error, Error.t()}}) :: {Plug.Conn.t(), {:ok, License.t()} | {:error, Error.t()}}
    def verify_license({conn, {:ok, signed_license}}) when is_binary(signed_license) and byte_size(signed_license) > 0 do
      case Zachaeus.verify(signed_license) do
        {:ok, %License{identifier: identifier, plan: plan}} = result ->
          conn =
            conn
            |> put_private(:zachaeus_identifier, identifier)
            |> put_private(:zachaeus_plan, plan)

          {conn, result}
        {:error, %Error{}} = error ->
          {conn, error}
        _unknown_error ->
          {conn, {:error, %Error{code: :verification_failed, message: "Unable to verify the license to to an unknown error"}}}
      end
    end
    def verify_license({conn, {:error, %Error{}} = error}),
      do: {conn, error}
    def verify_license({conn, _invalid_signed_license_or_error}),
      do: {conn, {:error, %Error{code: :verification_failed, message: "Unable to verify the license due to an invalid type"}}}

    @doc """
    Validates a license whether it has not expired.
    When the license could not be verified by `verify_license` it forwards this error.

    ## Example
        {conn, {:ok, %License{...}} = Zachaeus.Plug.validate_license({conn, {:ok, %License{...}}})
    """
    @spec validate_license({Plug.Conn.t(), {:ok, License.t()} | {:error, Error.t()}}) :: {Plug.Conn.t(), {:ok, License.t()} | {:error, Error.t()}}
    def validate_license({conn, {:ok, %License{} = license} = result}) do
      case License.validate(license) do
        {:ok, remaining_seconds} ->
          conn = conn
            |> put_private(:zachaeus_remaining_seconds, remaining_seconds)

          {conn, result}
        {:error, %Error{}} = error ->
          {conn, error}
        _unknown_error ->
          {conn, {:error, %Error{code: :validation_failed, message: "Unable to validate license due to an unknown error"}}}
      end
    end
    def validate_license({conn, {:error, %Error{}} = error}),
      do: {conn, error}
    def validate_license({conn, _invalid_license_or_error}),
      do: {conn, {:error, %Error{code: :validation_failed, message: "Unable to validate license due to an invalid type"}}}

    ## -- PLUG INFORMATION FUNCTIONS
    @doc """
    Get the identifier assigned with the license.

    ## Example
        "user_1" = zachaeus_identifier(conn)
    """
    @spec zachaeus_identifier(Plug.Conn.t()) :: String.t() | nil
    def zachaeus_identifier(conn), do: conn.private[:zachaeus_identifier]

    @doc """
    Get the plan assigned with the license.

    ## Example
        "standard_plan" = zachaeus_plan(conn)
    """
    @spec zachaeus_plan(Plug.Conn.t()) :: String.t() | nil
    def zachaeus_plan(conn), do: conn.private[:zachaeus_plan]

    @doc """
    Get the remaining seconds of the license.

    ## Example
        17436373 = zachaeus_remaining_seconds(conn)
    """
    @spec zachaeus_remaining_seconds(Plug.Conn.t()) :: Integer.t() | nil
    def zachaeus_remaining_seconds(conn), do: conn.private[:zachaeus_remaining_seconds]
  end
end
