defmodule Zachaeus do
  @moduledoc """
  Zachaeus is a simple and easy to use licensing system, which uses asymmetric signing to generate and validate licenses.
  A generated license contains all relevant data, which is essential for a simple licensing system.
  Due to the nature of a zachaeus license, it can be used without a database, if you simply want to verify the validity of a license.

  ## Technical details
  - The license token is using the (easy to use) asymmetric signing from NaCl
  - The license token is encoded with Base64 in an urlsafe format
  - The timestamp(s) used within zachaeus are encoded using the UTC timezone
  - The license itself is simply encoded as a pipe separated string

  ## Features
  - Generate public/private key(s) with a mix task
  - Generate license(s) with a mix task and the given license data
  - Contains an authentication plug which is compatible with web frameworks e.g. Phoenix
  - No need to store the private key(s), used for license generation, on servers outside your organization
  """
  alias Zachaeus.{Error, License}
  alias Salty.Sign.Ed25519

  @doc """
  Signs a license with the configured secret key and returns an urlsafe Base64 encoded license string.

  ## Examples
      Zachaeus.sign(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:error, %Zachaeus.Error{code: :unconfigured_secret_key, message: "There is no secret key configured for your application"}}

      Zachaeus.sign(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:ok, "signed_license..."}
  """
  @spec sign(license :: License.t()) :: {:ok, License.signed()} | {:error, Error.t()}
  def sign(license) do
    with {:ok, secret_key} <- fetch_configured_secret_key(), do: sign(license, secret_key)
  end

  @doc """
  Signs a license with the secret key and returns an urlsafe Base64 encoded license string.

  ## Examples
      iex> Zachaeus.sign(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]}, "invalid_secret_key")
      {:error, %Zachaeus.Error{code: :invalid_secret_key, message: "The given secret key must have a size of 64 bytes"}}

      iex> Zachaeus.sign(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]}, 123123)
      {:error, %Zachaeus.Error{code: :invalid_secret_key, message: "The given secret key has an invalid type"}}

      iex> {:ok, _public_key, secret_key} = Salty.Sign.Ed25519.keypair()
      iex> Zachaeus.sign("invalid_license_type", secret_key)
      {:error, %Zachaeus.Error{code: :invalid_license_type, message: "Unable to serialize license due to an invalid type"}}

      {:ok, _public_key, secret_key} = Salty.Sign.Ed25519.keypair()
      Zachaeus.sign(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]}, secret_key)
      {:ok, "signed_license..."}
  """
  @spec sign(license :: License.t(), secret_key :: binary()) :: {:ok, License.signed()} | {:error, Error.t()}
  def sign(license, secret_key) do
    with {:ok, serialized_license}   <- License.serialize(license),
         {:ok, validated_secret_key} <- validate_secret_key(secret_key),
         {:ok, license_signature}    <- Ed25519.sign_detached(serialized_license, validated_secret_key)
    do
      encode_signed_license(license_signature <> serialized_license)
    end
  end

  @doc """
  Verifies a signed license with the configured public key.

  ## Examples
      Zachaeus.verify("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...")
      {:error, %Zachaeus.Error{code: :unconfigured_public_key, message: "There is no public key configured for your application"}}

      Zachaeus.verify("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...")
      {:ok, %Zachaeus.License{...}}
  """
  @spec verify(signed_license :: License.signed()) :: {:ok, License.t()} | {:error, Error.t()}
  def verify(signed_license) do
    with {:ok, public_key} <- fetch_configured_public_key(), do: verify(signed_license, public_key)
  end

  @doc """
  Verifies a given signed license string with a given public key.

  ## Examples
      iex> Zachaeus.verify("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...", "invalid_public_key")
      {:error, %Zachaeus.Error{code: :invalid_public_key, message: "The given public key must have a size of 32 bytes"}}

      iex> Zachaeus.verify("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...", 123123)
      {:error, %Zachaeus.Error{code: :invalid_public_key, message: "The given public key has an invalid type"}}

      iex> {:ok, public_key, _secret_key} = Salty.Sign.Ed25519.keypair()
      iex> Zachaeus.verify("invalid_license", public_key)
      {:error, %Zachaeus.Error{code: :signature_not_found, message: "Unable to extract the signature from the signed license"}}

      {:ok, public_key, _secret_key} = Salty.Sign.Ed25519.keypair()
      Zachaeus.verify("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...", public_key)
      {:ok, %Zachaeus.License{...}}
  """
  @spec verify(signed_license :: License.signed(), public_key :: binary()) :: {:ok, License.t()} | {:error, Error.t()}
  def verify(signed_license, public_key) do
    with {:ok, validated_signed_license}      <- validate_signed_license(signed_license),
         {:ok, validated_public_key}          <- validate_public_key(public_key),
         {:ok, decoded_signed_license}        <- decode_signed_license(validated_signed_license),
         {:ok, signature, serialized_license} <- extract_signature(decoded_signed_license)
    do
      case Ed25519.verify_detached(signature, serialized_license, validated_public_key) do
        :ok ->
          License.deserialize(serialized_license)
        _verification_failed ->
          {:error, %Zachaeus.Error{code: :license_tampered, message: "The license might be tampered as the signature does not match to the license data"}}
      end
    end
  end

  @doc """
  Validates a signed license with a configured public key.

  ## Examples
      iex> Zachaeus.validate("invalid_license")
      {:error, %Zachaeus.Error{code: :signature_not_found, message: "Unable to extract the signature from the signed license"}}

      Zachaeus.validate("QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk5")
      {:ok, 5680217709}
  """
  @spec validate(signed_license :: License.signed()) :: {:ok, Integer.t()} | {:error, Error.t()}
  def validate(signed_license) do
    with {:ok, public_key} <- fetch_configured_public_key(), do: validate(signed_license, public_key)
  end

  @doc """
  Validates a signed license with a given public key.

  ## Examples
      iex> Zachaeus.validate("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...", "invalid_public_key")
      {:error, %Zachaeus.Error{code: :invalid_public_key, message: "The given public key must have a size of 32 bytes"}}

      iex> Zachaeus.validate("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...", 123123)
      {:error, %Zachaeus.Error{code: :invalid_public_key, message: "The given public key has an invalid type"}}

      iex> Zachaeus.validate("invalid_license", <<79, 86, 220, 100, 153, 39, 235, 176, 108, 13, 46, 255, 174, 250, 72, 103, 31, 24, 183, 231, 117, 63, 187, 222, 24, 56, 97, 27, 0, 45, 106, 227>>)
      {:error, %Zachaeus.Error{code: :signature_not_found, message: "Unable to extract the signature from the signed license"}}

      Zachaeus.validate("QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk5", <<79, 86, 220, 100, 153, 39, 235, 176, 108, 13, 46, 255, 174, 250, 72, 103, 31, 24, 183, 231, 117, 63, 187, 222, 24, 56, 97, 27, 0, 45, 106, 227>>)
      {:ok, 5680217709}
  """
  @spec validate(signed_license :: License.signed(), public_key :: String.t()) :: {:ok, Integer.t()} | {:error, Error.t()}
  def validate(signed_license, public_key) do
    with {:ok, license} <- verify(signed_license, public_key), do: License.validate(license)
  end


  @doc """
  Checks a signed license with the configured public key and indicates whether it is valid using a boolean.

  ## Examples
      iex> Zachaeus.valid?("QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk3")
      false

      iex> Zachaeus.valid?("invalid_license_type")
      false

      iex> Zachaeus.valid?("QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk5")
      true
  """
  @spec valid?(signed_license :: License.signed()) :: boolean()
  def valid?(signed_license) do
    case verify(signed_license) do
      {:ok, license} -> License.valid?(license)
      _verify_failed -> false
    end
  end

  @doc """
  Checks a signed license with a given public key and indicates whether it is valid using a boolean.

  ## Examples
      iex> Zachaeus.valid?("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...", "invalid_public_key")
      false

      iex> Zachaeus.valid?("lzcAxWfls4hDHs8fHwJu53AWsxX08KYpxGUwq4qsc...", 123123)
      false

      iex> Zachaeus.valid?("invalid_license", <<79, 86, 220, 100, 153, 39, 235, 176, 108, 13, 46, 255, 174, 250, 72, 103, 31, 24, 183, 231, 117, 63, 187, 222, 24, 56, 97, 27, 0, 45, 106, 227>>)
      false

      iex> Zachaeus.valid?("QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk5", <<79, 86, 220, 100, 153, 39, 235, 176, 108, 13, 46, 255, 174, 250, 72, 103, 31, 24, 183, 231, 117, 63, 187, 222, 24, 56, 97, 27, 0, 45, 106, 227>>)
      true
  """
  @spec valid?(signed_license :: License.signed(), public_key :: binary()) :: boolean()
  def valid?(signed_license, public_key) do
    case verify(signed_license, public_key) do
      {:ok, license} -> License.valid?(license)
      _verify_failed -> false
    end
  end

  ## -- SETTINGS HELPER FUNCTIONS
  @spec fetch_configured_public_key() :: {:ok, binary()} | {:error, Error.t()}
  defp fetch_configured_public_key() do
    case Application.fetch_env(:zachaeus, :public_key) do
      {:ok, encoded_public_key} when is_binary(encoded_public_key) ->
        case Base.url_decode64(encoded_public_key, padding: false) do
          {:ok, _public_key} = decoded_public_key ->
            decoded_public_key
          _error_decoding_public_key ->
            {:error, %Error{code: :decoding_failed, message: "Unable to decode the configured public key due to an error"}}
        end
      {:ok, public_key} ->
        {:ok, public_key}
      _public_key_not_found ->
        {:error, %Error{code: :public_key_unconfigured, message: "There is no public key configured for your application"}}
    end
  end

  @spec fetch_configured_secret_key() :: {:ok, binary()} | {:error, Error.t()}
  defp fetch_configured_secret_key() do
    case Application.fetch_env(:zachaeus, :secret_key) do
      {:ok, encoded_secret_key} when is_binary(encoded_secret_key) ->
        case Base.url_decode64(encoded_secret_key, padding: false) do
          {:ok, _secret_key} = decoded_secret_key ->
            decoded_secret_key
          _error_decoding_secret_key ->
            {:error, %Error{code: :decoding_failed, message: "Unable to decode the configured secret key due to an error"}}
        end
      {:ok, secret_key} ->
        {:ok, secret_key}
      _secret_key_not_found ->
        {:error, %Error{code: :secret_key_unconfigured, message: "There is no secret key configured for your application"}}
    end
  end

  ## -- VALIDATION HELPER FUNCTIONS
  @spec validate_signed_license(signed_license :: License.signed()) :: {:ok, License.signed()} | {:error, Error.t()}
  defp validate_signed_license(signed_license) when is_binary(signed_license) and byte_size(signed_license) > 0,
    do: {:ok, signed_license}
  defp validate_signed_license(signed_license) when is_binary(signed_license) and byte_size(signed_license) <= 0,
    do: {:error, %Error{code: :empty_signed_license, message: "The given signed license cannot be empty"}}
  defp validate_signed_license(_invalid_signed_license),
    do: {:error, %Error{code: :invalid_signed_license, message: "The given signed license has an invalid type"}}

  @spec validate_public_key(public_key :: binary()) :: {:ok, String.t()} | {:error, Error.t()}
  defp validate_public_key(public_key) when is_binary(public_key) and byte_size(public_key) == 32,
    do: {:ok, public_key}
  defp validate_public_key(public_key) when is_binary(public_key) and byte_size(public_key) != 32,
    do: {:error, %Error{code: :invalid_public_key, message: "The given public key must have a size of 32 bytes"}}
  defp validate_public_key(_invalid_public_key),
    do: {:error, %Error{code: :invalid_public_key, message: "The given public key has an invalid type"}}

  @spec validate_secret_key(secret_key :: binary()) :: {:ok, String.t()} | {:error, Error.t()}
  defp validate_secret_key(secret_key) when is_binary(secret_key) and byte_size(secret_key) == 64,
    do: {:ok, secret_key}
  defp validate_secret_key(secret_key) when is_binary(secret_key) and byte_size(secret_key) != 64,
    do: {:error, %Error{code: :invalid_secret_key, message: "The given secret key must have a size of 64 bytes"}}
  defp validate_secret_key(_invalid_secret_key),
    do: {:error, %Error{code: :invalid_secret_key, message: "The given secret key has an invalid type"}}

  ## -- GENERAL HELPER FUNCTIONS
  @spec encode_signed_license(license_data :: String.t()) :: {:ok, License.signed()} | {:error, Error.t()}
  defp encode_signed_license(license_data) when is_binary(license_data) and byte_size(license_data) > 0,
    do: {:ok, Base.url_encode64(license_data, padding: false)}
  defp encode_signed_license(_invalid_license_data),
    do: {:error, %Error{code: :encoding_failed, message: "Unable to encode the given license data"}}

  @spec decode_signed_license(license_data :: License.signed()) :: {:ok, String.t()} | {:error, Error.t()}
  defp decode_signed_license(license_data) when is_binary(license_data) and byte_size(license_data) > 0,
    do: Base.url_decode64(license_data, padding: false)
  defp decode_signed_license(_invalid_license_data),
    do: {:error, %Error{code: :decoding_failed, message: "Unable to decode the given license data"}}

  @spec extract_signature(signed_license :: String.t()) :: {:ok, String.t(), License.serialized()} | {:error, Error.t()}
  defp extract_signature(<<signature::binary-size(64), serialized_license::binary>>),
    do: {:ok, signature, serialized_license}
  defp extract_signature(signed_license) when is_binary(signed_license),
    do: {:error, %Error{code: :signature_not_found, message: "Unable to extract the signature from the signed license"}}
  defp extract_signature(_invalid_signed_license),
    do: {:error, %Error{code: :invalid_signed_license, message: "Unable to extract the signature due to an invalid type"}}
end
