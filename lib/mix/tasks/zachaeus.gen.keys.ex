defmodule Mix.Tasks.Zachaeus.Gen.Keys do
  @shortdoc "Generates the public/secret key pair"

  @moduledoc """
  Generates a Zachaeus key pair.

      mix zachaeus.gen.keys

  Generation of a public/secret key pair in order to sign/verify licenses.
  The generated key pair can to be stored in your `config.exs` according to the instructions.


  This task does not require any arguments to work.
  """
  use Mix.Task

  @doc false
  @impl Mix.Task
  def run(_args) do
    with {:ok, _salty_started} <- Application.ensure_all_started(:salty),
         {:ok, raw_public_key, raw_secret_key} <- Salty.Sign.Ed25519.keypair(),
         {:ok, public_key} <- encode_key(raw_public_key),
         {:ok, secret_key} <- encode_key(raw_secret_key)
    do
      Mix.shell().info("""
      Modify your config.exs file and add the following configuration as indicated below:
      """)

      Mix.shell().info([
        :green,
        """
          config :zachaeus,
              public_key: "#{public_key}",
              secret_key: "#{secret_key}"
        """
      ])

      Mix.shell().info("""
      If you only want to verify licenses, modify your config.exs file and add the following configuration as indicated below:
      """)

      Mix.shell().info([
        :green,
        """
          config :zachaeus,
            public_key: "#{public_key}"
        """
      ])

      Mix.shell().info("""
      For generating licenses, modify your config.exs file and add the following configuration as indicated below:
      """)

      Mix.shell().info([
        :green,
        """
          config :zachaeus,
            secret_key: "#{secret_key}"
        """
      ])

      Mix.shell().info([
        :red,
        """
        HINT: Please make a backup of both keys, otherwise you will lose the ability to verify (already issued) licenses.
        """
      ])
    else
      {:error, message} ->
        Mix.raise("""
        ERROR: #{message}

        Unable to generate public/secret key pair due to the following error:
        """)
    end
  end

  ## -- HELPER FUNCTIONS
  @spec encode_key(key :: binary()) :: {:ok, String.t()} | {:error, String.t()}
  defp encode_key(key) when is_binary(key) and byte_size(key) > 0,
    do: {:ok, Base.url_encode64(key, padding: false)}

  defp encode_key(_invalid_key),
    do: {:error, "Unable to encode keys due to invalid data"}
end
