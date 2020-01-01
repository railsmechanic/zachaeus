defmodule ZachaeusTest do
  use ExUnit.Case, async: true
  doctest Zachaeus

  alias Zachaeus.{Error, License}
  alias Salty.Sign.Ed25519

  setup_all do
    {:ok, %{
      license: %License{
        identifier: "user_1",
        plan: "default_plan",
        valid_from: ~U[2019-01-01 00:00:00Z],
        valid_until: ~U[2199-12-31 23:59:59Z]
      },
      serialized_license: "user_1|default_plan|1546300800|7258118399",
      signed_license: "QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk5",
      tampered_signed_license: "QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk4",
      public_key: Application.fetch_env!(:zachaeus, :public_key),
      secret_key: Application.fetch_env!(:zachaeus, :secret_key),
    }}
  end

  describe "sign/1" do
    setup context do
      on_exit(fn ->
        Application.put_env(:zachaeus, :secret_key, context.secret_key)
      end)
    end

    test "with an unconfigured secret key", context do
      Application.delete_env(:zachaeus, :secret_key)
      assert {:error, %Error{code: :secret_key_unconfigured}} = Zachaeus.sign(context.license)
    end

    test "with an invalid secret key", context do
      # -> nil
      secret_key = nil
      Application.put_env(:zachaeus, :secret_key, secret_key)
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license)

      # -> empty string
      secret_key = ""
      Application.put_env(:zachaeus, :secret_key, secret_key)
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license)

      # -> invalid string
      secret_key = "%%%%"
      Application.put_env(:zachaeus, :secret_key, secret_key)
      assert {:error, %Error{code: :decoding_failed}} = Zachaeus.sign(context.license)

      # -> invalid size
      secret_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      Application.put_env(:zachaeus, :secret_key, secret_key)
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license)

      # -> invalid type
      secret_key = 123
      Application.put_env(:zachaeus, :secret_key, secret_key)
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license)
    end

    test "with valid data", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.license)
      assert {:ok, decoded_signed_license} = Base.url_decode64(signed_license, padding: false)
      assert <<_signature::binary-size(64), serialized_license::binary>> = decoded_signed_license
      assert serialized_license == context.serialized_license
    end
  end

  describe "sign/2" do
    test "with an invalid secret key", context do
      # -> nil
      secret_key = nil
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license, secret_key)

      # -> empty string
      secret_key = ""
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license, secret_key)

      # -> invalid size
      secret_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license, secret_key)

      # -> invalid type
      secret_key = 123
      assert {:error, %Error{code: :invalid_secret_key}} = Zachaeus.sign(context.license, secret_key)
    end

    test "with valid data", context do
      assert {:ok, secret_key} = Base.url_decode64(context.secret_key, padding: false)
      assert {:ok, signed_license} = Zachaeus.sign(context.license, secret_key)
      assert {:ok, decoded_signed_license} = Base.url_decode64(signed_license, padding: false)
      assert <<_signature::binary-size(64), serialized_license::binary>> = decoded_signed_license
      assert serialized_license == context.serialized_license
    end
  end

  describe "verify/1" do
    setup context do
      on_exit(fn ->
        Application.put_env(:zachaeus, :public_key, context.public_key)
      end)
    end

    test "with an unconfigured public key", context do
      Application.delete_env(:zachaeus, :public_key)
      assert {:error, %Error{code: :public_key_unconfigured}} = Zachaeus.verify(context.signed_license)
    end

    test "with an invalid public key", context do
      # -> nil
      public_key = nil
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license)

      # -> empty string
      public_key = ""
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license)

      # -> invalid string
      public_key = "%%%%"
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :decoding_failed}} = Zachaeus.verify(context.signed_license)

      # -> invalid size
      public_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license)

      # -> invalid type
      public_key = 123
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license)
    end

    test "with a tampered license", context do
      assert {:error, %Error{code: :license_tampered}} = Zachaeus.verify(context.tampered_signed_license)
    end

    test "with valid data", context do
      assert {:ok, license} = Zachaeus.verify(context.signed_license)
      assert {:ok, decoded_signed_license} = Base.url_decode64(context.signed_license, padding: false)
      assert <<signature::binary-size(64), serialized_license::binary>> = decoded_signed_license
      assert {:ok, decoded_public_key} = Base.url_decode64(context.public_key, padding: false)
      assert :ok == Ed25519.verify_detached(signature, serialized_license, decoded_public_key)
      assert license == context.license
    end
  end

  describe "verify/2" do
    test "with an invalid public key", context do
      # -> nil
      public_key = nil
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license, public_key)

      # -> empty string
      public_key = ""
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license, public_key)

      # -> invalid size
      public_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license, public_key)

      # -> invalid type
      public_key = 123
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.verify(context.signed_license, public_key)
    end

    test "with a tampered license", context do
      assert {:ok, decoded_public_key} = Base.url_decode64(context.public_key, padding: false)
      assert {:error, %Error{code: :license_tampered}} = Zachaeus.verify(context.tampered_signed_license, decoded_public_key)
    end

    test "with valid data", context do
      assert {:ok, decoded_public_key} = Base.url_decode64(context.public_key, padding: false)
      assert {:ok, license} = Zachaeus.verify(context.signed_license, decoded_public_key)
      assert {:ok, decoded_signed_license} = Base.url_decode64(context.signed_license, padding: false)
      assert <<signature::binary-size(64), serialized_license::binary>> = decoded_signed_license
      assert :ok == Ed25519.verify_detached(signature, serialized_license, decoded_public_key)
      assert license == context.license
    end
  end

  describe "validate/1" do
    setup context do
      on_exit(fn ->
        Application.put_env(:zachaeus, :public_key, context.public_key)
      end)
    end

    test "with an unconfigured public key", context do
      Application.delete_env(:zachaeus, :public_key)
      assert {:error, %Error{code: :public_key_unconfigured}} = Zachaeus.validate(context.signed_license)
    end

    test "with an invalid public key", context do
      # -> nil
      public_key = nil
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license)

      # -> empty string
      public_key = ""
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license)

      # -> invalid string
      public_key = "%%%%"
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :decoding_failed}} = Zachaeus.validate(context.signed_license)

      # -> invalid size
      public_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license)

      # -> invalid type
      public_key = 123
      Application.put_env(:zachaeus, :public_key, public_key)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license)
    end

    test "with a tampered license", context do
      assert {:error, %Error{code: :license_tampered}} = Zachaeus.validate(context.tampered_signed_license)
    end

    test "with valid data", context do
      assert Zachaeus.validate(context.signed_license) == License.validate(context.license)
    end
  end

  describe "validate/2" do
    test "with an invalid public key", context do
      # -> nil
      public_key = nil
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license, public_key)

      # -> empty string
      public_key = ""
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license, public_key)

      # -> invalid size
      public_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license, public_key)

      # -> invalid type
      public_key = 123
      assert {:error, %Error{code: :invalid_public_key}} = Zachaeus.validate(context.signed_license, public_key)
    end

    test "with a tampered license", context do
      assert {:ok, decoded_public_key} = Base.url_decode64(context.public_key, padding: false)
      assert {:error, %Error{code: :license_tampered}} = Zachaeus.validate(context.tampered_signed_license, decoded_public_key)
    end

    test "with valid data", context do
      assert {:ok, decoded_public_key} = Base.url_decode64(context.public_key, padding: false)
      assert Zachaeus.validate(context.signed_license, decoded_public_key) == License.validate(context.license)
    end
  end

  describe "valid?/1" do
    setup context do
      on_exit(fn ->
        Application.put_env(:zachaeus, :public_key, context.public_key)
      end)
    end

    test "with an unconfigured public key", context do
      Application.delete_env(:zachaeus, :public_key)
      refute Zachaeus.valid?(context.signed_license)
    end

    test "with an invalid public key", context do
      # -> nil
      public_key = nil
      Application.put_env(:zachaeus, :public_key, public_key)
      refute Zachaeus.valid?(context.signed_license)

      # -> empty string
      public_key = ""
      Application.put_env(:zachaeus, :public_key, public_key)
      refute Zachaeus.valid?(context.signed_license)

      # -> invalid string
      public_key = "%%%%"
      Application.put_env(:zachaeus, :public_key, public_key)
      refute Zachaeus.valid?(context.signed_license)

      # -> invalid size
      public_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      Application.put_env(:zachaeus, :public_key, public_key)
      refute Zachaeus.valid?(context.signed_license)

      # -> invalid type
      public_key = 123
      Application.put_env(:zachaeus, :public_key, public_key)
      refute Zachaeus.valid?(context.signed_license)
    end

    test "with a tampered license", context do
      refute Zachaeus.valid?(context.tampered_signed_license)
    end

    test "with valid data", context do
      assert Zachaeus.valid?(context.signed_license)
      assert License.valid?(context.license)
      assert Zachaeus.valid?(context.signed_license) == License.valid?(context.license)
    end
  end

  describe "valid?/2" do
    test "with an invalid public key", context do
      # -> nil
      public_key = nil
      refute Zachaeus.valid?(context.signed_license, public_key)

      # -> empty string
      public_key = ""
      refute Zachaeus.valid?(context.signed_license, public_key)

      # -> invalid size
      public_key = :crypto.strong_rand_bytes(63) |> Base.url_encode64(padding: false)
      refute Zachaeus.valid?(context.signed_license, public_key)

      # -> invalid type
      public_key = 123
      refute Zachaeus.valid?(context.signed_license, public_key)
    end

    test "with a tampered license", context do
      assert {:ok, decoded_public_key} = Base.url_decode64(context.public_key, padding: false)
      refute Zachaeus.valid?(context.tampered_signed_license, decoded_public_key)
    end

    test "with valid data", context do
      assert {:ok, decoded_public_key} = Base.url_decode64(context.public_key, padding: false)
      assert Zachaeus.valid?(context.signed_license, decoded_public_key)
      assert License.valid?(context.license)
      assert Zachaeus.valid?(context.signed_license, decoded_public_key) == License.valid?(context.license)
    end
  end
end
