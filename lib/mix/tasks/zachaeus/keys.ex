defmodule Mix.Tasks.Zachaeus.Keys do
  use Mix.Task

  @impl Mix.Task
  @shortdoc "Generates a public/secret key pair for your application"
  def run(_args) do
    with {:ok, _} <- Application.ensure_all_started(:salty), {:ok, public_key, secret_key} <- Salty.Sign.Ed25519.keypair() do
        Mix.shell().info("PUBLIC KEY: #{Base.url_encode64(public_key, padding: false)}")
        Mix.shell().info("SECRET KEY: #{Base.url_encode64(secret_key, padding: false)}")
    else
      _any_error ->
        Mix.shell().error("Unable to generate keys")
    end
  end
end
