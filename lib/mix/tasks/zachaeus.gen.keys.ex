defmodule Mix.Tasks.Zachaeus.Gen.Keys do
  @moduledoc """
  Generate Coherence controllers.
  Use this task to generate the Coherence controllers when
  you what to customize the controllers' behavior.
  ## Examples
      # Install all the controllers for the coherence opts
      # defined in your `config/config.exs` file
      mix coh.gen.controllers
  Once the controllers have been generated, you must update your
  `router.ex` file to properly scope the generated controller(s).
  For example:
      # lib/my_app_web
      def MyAppWeb.Router do
        # ...
        scope "/", MyAppWeb do
          pipe_through :browser
          coherence_routes()
        end
        scope "/", MyAppWeb do
          pipe_through :protected
          coherence_routes :protected
        end
        # ...
      end
  ## Options
  * `--web-path` override the web path
  * `--no-confirm` silently overwrite files
  """
  use Mix.Task

  @shortdoc "Generates the required public/secret key pair"

  @impl Mix.Task
  def run(_args) do
    with {:ok, _} <- Application.ensure_all_started(:salty),
         {:ok, raw_public_key, raw_secret_key} <- Salty.Sign.Ed25519.keypair(),
         {:ok, public_key} <- encode_key(raw_public_key),
         {:ok, secret_key} <- encode_key(raw_secret_key)
    do
      Mix.shell().info("""

      Modify your config.exs file and add the following configuration as indicated below:

        config :zachaeus,
          public_key: "#{public_key}",
          secret_key: "#{secret_key}"


      If you only want to verify licenses, modify your config.exs file and add the following configuration as indicated below:

        config :zachaeus,
          public_key: "#{public_key}"

      For generating licenses, modify your config.exs file and add the following configuration as indicated below:

        config :zachaeus,
          secret_key: "#{secret_key}"


      >> Please make a backup of your keys, otherwise you will lose the ability to verify already issued licenses. <<
      """)
    else
      {:error, message} ->
        Mix.raise(
          """
          Unable to generate public/secret key pair due to the following error:

          #{message}
          """
        )
    end
  end

  ## -- HELPER FUNCTIONS
  @spec encode_key(key :: binary()) :: {:ok, String.t()} | {:error, String.t()}
  defp encode_key(key) when is_binary(key) and byte_size(key) > 0,
    do: {:ok, Base.url_encode64(key, padding: false)}
  defp encode_key(_invalid_key),
    do: {:error, "Unable to encode key(s) due to invalid data"}

end
