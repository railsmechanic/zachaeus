defmodule Zachaeus.LicenseTest do
  use ExUnit.Case, async: true
  doctest Zachaeus.License

  alias Zachaeus.{Error, License}

  setup_all do
    {:ok, %{
      license: %License{
        identifier: "user_1",
        plan: "default_plan",
        valid_from: ~U[2019-01-01 00:00:00Z],
        valid_until: ~U[2199-12-31 23:59:59Z]
      }
    }}
  end

  describe "serialize/1" do
    test "with invalid identifier", context do
      # -> nil
      license = %{context.license | identifier: nil}
      assert {:error, %Error{code: :empty_identifier}} = License.serialize(license)

      # -> empty string
      license = %{context.license | identifier: ""}
      assert {:error, %Error{code: :empty_identifier}} = License.serialize(license)

      # -> invalid type
      license = %{context.license | identifier: %{}}
      assert {:error, %Error{code: :invalid_string_type}} = License.serialize(license)

      # -> reserved character
      license = %{context.license | identifier: "|"}
      assert {:error, %Error{code: :invalid_identifer}} = License.serialize(license)
    end

    test "with invalid plan", context do
      # -> nil
      license = %{context.license | plan: nil}
      assert {:error, %Error{code: :empty_plan}} = License.serialize(license)

      # -> empty string
      license = %{context.license | plan: ""}
      assert {:error, %Error{code: :empty_plan}} = License.serialize(license)

      # -> invalid type
      license = %{context.license | plan: %{}}
      assert {:error, %Error{code: :invalid_string_type}} = License.serialize(license)

      # -> reserved character
      license = %{context.license | plan: "|"}
      assert {:error, %Error{code: :invalid_plan}} = License.serialize(license)
    end

    test "with invalid valid_from", context do
      # -> nil
      license = %{context.license | valid_from: nil}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)

      # -> empty string
      license = %{context.license | valid_from: ""}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)

      # -> invalid type
      license = %{context.license | valid_from: %{}}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)

      # -> reserved character
      license = %{context.license | valid_from: "|"}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)
    end

    test "with invalid valid_until", context do
      # -> nil
      license = %{context.license | valid_until: nil}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)

      # -> empty string
      license = %{context.license | valid_until: ""}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)

      # -> invalid type
      license = %{context.license | valid_until: %{}}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)

      # -> reserved character
      license = %{context.license | valid_until: "|"}
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.serialize(license)
    end

    test "with invalid time range", context do
      license = %{context.license | valid_from: context.license.valid_until, valid_until: context.license.valid_from}
      assert {:error, %Error{code: :invalid_timerange}} = License.serialize(license)
    end

    test "with invalid license type" do
      assert {:error, %Error{code: :invalid_license_type}} = License.serialize(%{})
    end

    test "with valid data", context do
      assert {:ok, serialized_license} = License.serialize(context.license)
      assert "user_1|default_plan|1546300800|7258118399" = serialized_license
    end
  end

  describe "deserialize/1" do
    test "with invalid identifier" do
      # -> nil
      serialized_license = "|default_plan|1546300800|7258118399"
      assert {:error, %Error{code: :invalid_license_format,}} = License.deserialize(serialized_license)

      # -> empty string
      serialized_license = " |default_plan|1546300800|7258118399"
      assert {:error, %Error{code: :empty_identifier,}} = License.deserialize(serialized_license)
    end

    test "with invalid plan" do
      # -> nil
      serialized_license = "user_1||1546300800|7258118399"
      assert {:error, %Error{code: :invalid_license_format,}} = License.deserialize(serialized_license)

      # -> empty string
      serialized_license = "user_1| |1546300800|7258118399"
      assert {:error, %Error{code: :empty_plan,}} = License.deserialize(serialized_license)
    end

    test "with invalid valid_from" do
      # -> nil
      serialized_license = "user_1|default_plan||7258118399"
      assert {:error, %Error{code: :invalid_license_format}} = License.deserialize(serialized_license)

      # -> empty string
      serialized_license = "user_1|default_plan| |7258118399"
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.deserialize(serialized_license)

      # -> invalid type
      serialized_license = "user_1|default_plan|invalid|7258118399"
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.deserialize(serialized_license)
    end

    test "with invalid valid_until" do
      # -> nil
      serialized_license = "user_1|default_plan|1546300800|"
      assert {:error, %Error{code: :invalid_license_format}} = License.deserialize(serialized_license)

      # -> empty string
      serialized_license = "user_1|default_plan|1546300800| "
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.deserialize(serialized_license)

      # -> invalid type
      serialized_license = "user_1|default_plan|1546300800|invalid"
      assert {:error, %Error{code: :invalid_timestamp_type}} = License.deserialize(serialized_license)
    end

    test "with invalid time range" do
      serialized_license = "user_1|default_plan|7258118399|1546300800"
      assert {:error, %Error{code: :invalid_timerange}} = License.deserialize(serialized_license)
    end

    test "with invalid serialized license format" do
      serialized_license = "user_1|default_plan|1546300800|7258118399|some|additional|data"
      assert {:error, %Error{code: :invalid_license_format}} = License.deserialize(serialized_license)

      serialized_license = "some|additional|data|user_1|default_plan|1546300800|7258118399"
      assert {:error, %Error{code: :invalid_license_format}} = License.deserialize(serialized_license)

      serialized_license = "absolutely_invalid_license_format"
      assert {:error, %Error{code: :invalid_license_format}} = License.deserialize(serialized_license)
    end

    test "with invalid serialized license type range" do
      assert {:error, %Error{code: :invalid_license_type}} = License.deserialize(%{})
    end

    test "with valid data", context do
      # - integer timestamp
      serialized_license = "user_1|default_plan|1546300800|7258118399"
      assert {:ok, license}  = License.deserialize(serialized_license)
      assert license = context.license

      # - float timestamp
      serialized_license = "user_1|default_plan|1546300800.0|7258118399.0"
      assert {:ok, license}  = License.deserialize(serialized_license)
      assert license = context.license
    end
  end

  describe "validate/1" do
    test "with a predated license", context do
      license = %{context.license | valid_from: ~U[2199-01-01 00:00:00Z]}
      assert {:error, %Error{code: :license_predated}} = License.validate(license)
    end

    test "with an outdated license", context do
      license = %{context.license | valid_until: ~U[2019-01-01 00:00:00Z]}
      assert {:error, %Error{code: :license_expired}} = License.validate(license)
    end

    test "with invalid license type" do
      assert {:error, %Error{code: :invalid_license_type}} = License.validate(%{})
    end

    test "with valid data", context do
      assert {:ok, remaining_seconds} = License.validate(context.license)
      assert is_integer(remaining_seconds)
      assert remaining_seconds > 0
    end
  end

  describe "valid?/1" do
    test "with a predated license", context do
      license = %{context.license | valid_from: ~U[2199-01-01 00:00:00Z]}
      refute License.valid?(license)
    end

    test "with an outdated license", context do
      license = %{context.license | valid_until: ~U[2019-01-01 00:00:00Z]}
      refute License.valid?(license)
    end

    test "with invalid license type" do
      refute License.valid?(%{})
    end

    test "with valid data", context do
      assert License.valid?(context.license)
    end
  end
end
