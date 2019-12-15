defmodule Zachaeus.License do
  @moduledoc """
  The license contains all relevant data which is essential for a simple licensing system.
  Due to the nature of a license, it can be used without a database, if you simply want to verify the validity of a license.
  """
  alias Zachaeus.Error

  ## -- MODULE ATTRIBUTES
  @license_timezone "Etc/UTC"
  @license_separator_regex ~r/\|/

  ## -- STRUCT DATA
  defstruct identifier: nil,
            plan: nil,
            valid_from: DateTime.utc_now(),
            valid_until: DateTime.utc_now()

  @typedoc """
  The license in the default format.

  ## License data
  - `identifier` represents users, entities etc.
  - `plan` represents e.g. a varying behaviour of your application
  - `valid_from` represents the start of the license
  - `valid_until` represents the end of the license
  """
  @type t() :: %__MODULE__{
          identifier: String.t(),
          plan: String.t(),
          valid_from: DateTime.t(),
          valid_until: DateTime.t()
        }

  @typedoc """
  The license in a serialized format.

  ## License encoding format
  - The license data (identifier, plan, valid_from, valid_until) is separated by a `|` (pipe).
  - None of the given license data is allowed to include a `|` (pipe) symbol (validation required).
  - All timestamps are encoded in unix format within the UTC timezone.

  ## Example
  Format:  [<identifier>|<plan>|<valid_from>|<valid_until>]
  Example: "my_user_id_1|default|1542279600|1573815600"
  """
  @type serialized() :: String.t()

  @typedoc """
  The serialized, signed and encoded license.

  ## Signed license string
      - The license is serialized, signed and an encoded string which contains the license data
      - The first 64 byte of the signed license string represents the verification hash

  ## Example
      Format: "VGVzdAJxQsXSrgYBkcwiOnWamiattqhhhNN_1jsY-LR_YbsoYpZ18-ogVSxWv7d8DlqzLSz9csqNtSzDk4y0JV5xaAE"
  """
  @type signed() :: String.t()

  ## -- FUNCTIONS
  @doc """
  Serialize a license into a formated string.

  ## Examples
      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:ok, "my_user_id_1|default|1542279600|1573815600"}

      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: 1, plan: "default", valid_from: "invalid datetime", valid_until: ~U[2019-11-15 11:00:00Z]})
      {:error, %Zachaeus.Error{code: :invalid_timestamp, message: "Unable to cast timestamp to DateTime"}}

      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: nil, plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:error, %Zachaeus.Error{code: :identifier_empty, message: "The given identifier cannot be empty"}}

      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: 1, plan: nil, valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:error, %Zachaeus.Error{code: :plan_empty, message: "The given plan cannot be empty"}}
  """
  @spec serialize(__MODULE__.t()) :: {:ok, __MODULE__.serialized()} | {:error, Zachaeus.error()}
  def serialize(%__MODULE__{identifier: raw_identifier, plan: raw_plan, valid_from: raw_valid_from, valid_until: raw_valid_until}) do
    with {:ok, casted_identifier}       <- cast_string(raw_identifier),
         {:ok, casted_plan}             <- cast_string(raw_plan),
         {:ok, casted_valid_from}       <- cast_datetime(raw_valid_from),
         {:ok, casted_valid_until}      <- cast_datetime(raw_valid_until),
         {:ok, identifier}              <- validate_identifier(casted_identifier),
         {:ok, plan}                    <- validate_plan(casted_plan),
         {:ok, valid_from, valid_until} <- validate_timerange(casted_valid_from, casted_valid_until) do
      {:ok, "#{identifier}|#{plan}|#{DateTime.to_unix(valid_from)}|#{DateTime.to_unix(valid_until)}"}
    end
  end
  def serialize(_invalid_license), do: {:error, %Error{code: :invalid_license, message: "Unable to serialize license due to an invalid type"}}

  @doc """
  Deserialize a license string into a license.

  ## Examples
      iex> Zachaeus.License.deserialize("my_user_id_1|default|1542279600|1573815600")
      {:ok, %Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]}}

      iex> Zachaeus.License.deserialize("my_user_id_1|default|invalid datetime|1573815600")
      {:error, %Zachaeus.Error{code: :invalid_timestamp, message: "Unable to cast timestamp to DateTime"}}

      iex> Zachaeus.License.deserialize(" |default|1542279600|1573815600")
      {:error, %Zachaeus.Error{code: :identifier_empty, message: "The given identifier cannot be empty"}}

      iex> Zachaeus.License.deserialize("my_user_id_1| |1542279600|1573815600")
      {:error, %Zachaeus.Error{code: :plan_empty, message: "The given plan cannot be empty"}}

      iex> Zachaeus.License.deserialize("absolutely_invalid_license_string")
      {:error, %Zachaeus.Error{code: :invalid_license_string, message: "Unable to deserialize license string due to an invalid format"}}
  """
  @spec deserialize(__MODULE__.serialized()) :: {:ok, __MODULE__.t()} | {:error, Zachaeus.error()}
  def deserialize(license_string) when is_binary(license_string) do
    case String.split(license_string, @license_separator_regex, trim: true) do
      [identifier_part, plan_part, valid_from_part, valid_until_part] ->
        with {:ok, casted_identifier}       <- cast_string(identifier_part),
             {:ok, casted_plan}             <- cast_string(plan_part),
             {:ok, casted_valid_from}       <- cast_datetime(valid_from_part),
             {:ok, casted_valid_until}      <- cast_datetime(valid_until_part),
             {:ok, identifier}              <- validate_identifier(casted_identifier),
             {:ok, plan}                    <- validate_plan(casted_plan),
             {:ok, valid_from, valid_until} <- validate_timerange(casted_valid_from, casted_valid_until) do
          {:ok,
           %__MODULE__{identifier: identifier, plan: plan, valid_from: valid_from, valid_until: valid_until}}
        end

      _invalid_license_string_format ->
        {:error, %Error{code: :invalid_license_string, message: "Unable to deserialize license string due to an invalid format"}}
    end
  end
  def deserialize(_invalid_license_string), do: {:error, %Error{code: :invalid_license_string, message: "Unable to deserialize license data due to an invalid type"}}

  @doc """
  Validate a given license and check whether its outdated or in an invalid format.
  When the license is valid, it returns the remaining license time in seconds.

  ## Examples
      iex> Zachaeus.License.validate(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-30 09:50:00Z]})
      {:error, %Zachaeus.Error{code: :license_outdated, message: "The license is outdated"}}
  """
  @spec validate(__MODULE__.t()) :: {:ok, Integer.t()} | {:error, Zachaeus.error()}
  def validate(%__MODULE__{valid_until: valid_until}) do
    with {:ok, valid_until} <- shift_datetime(valid_until), {:ok, validation_datetime} <- shift_datetime(DateTime.utc_now()) do
      case DateTime.compare(valid_until, validation_datetime) do
        :eq -> {:ok, DateTime.diff(valid_until, validation_datetime)}
        :gt -> {:ok, DateTime.diff(valid_until, validation_datetime)}
        _valid_timerange -> {:error, %Error{code: :license_outdated, message: "The license is outdated"}}
      end
    end
  end
  def validate(_invalid_license), do: {:error, %Error{code: :invalid_license, message: "The given license is invalid"}}

  ## -- CAST HELPER FUNCTIONS
  @spec cast_string(String.t() | Integer.t() | Float.t() | Atom.t() | nil) :: {:ok, String.t()} | {:error, Zachaeus.error()}
  defp cast_string(data) when is_binary(data), do: {:ok, String.trim(data)}
  defp cast_string(data) when is_number(data) or is_atom(data) or is_nil(data) do
    data
    |> to_string()
    |> cast_string()
  end
  defp cast_string(_invalid_data), do: {:error, %Error{code: :invalid_data, message: "Unable to cast data to String"}}

  @spec cast_datetime(DateTime.t() | Integer.t() | Float.t() | String.t()) :: {:ok, DateTime.t()} | {:error, Zachaeus.error()}
  defp cast_datetime(%DateTime{} = timestamp), do: shift_datetime(timestamp)
  defp cast_datetime(timestamp) when is_integer(timestamp) do
    case DateTime.from_unix(timestamp) do
      {:ok, %DateTime{} = timestamp} ->
        shift_datetime(timestamp)

      _unable_to_cast_to_datetime ->
        {:error, %Error{code: :invalid_timestamp, message: "Unable to cast timestamp to DateTime"}}
    end
  end
  defp cast_datetime(timestamp) when is_float(timestamp) do
    timestamp
    |> Kernel.trunc()
    |> cast_datetime()
  end
  defp cast_datetime(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {timestamp, _unparsable_data} ->
        cast_datetime(timestamp)

      _unable_to_cast_to_integer ->
        {:error, %Error{code: :invalid_timestamp, message: "Unable to cast timestamp to DateTime"}}
    end
  end
  defp cast_datetime(_invalid_timestamp), do: {:error, %Error{code: :invalid_timestamp, message: "Unable to cast timestamp to DateTime"}}

  ## -- VALIDATION HELPER FUNCTIONS
  @spec validate_identifier(String.t()) :: {:ok, String.t()} | {:error, Zachaeus.error()}
  defp validate_identifier(identifier) when is_binary(identifier) do
    cond do
      identifier |> String.trim() |> String.length() <= 0 ->
        {:error, %Error{code: :identifier_empty, message: "The given identifier cannot be empty"}}

      Regex.match?(@license_separator_regex, identifier) ->
        {:error, %Error{code: :identifier_invalid, message: "The given identifier contains a reserved character"}}

      true ->
        {:ok, identifier}
    end
  end
  defp validate_identifier(_invalid_identifier), do: {:error, %Error{code: :identifier_invalid, message: "The given identifier is not a String"}}

  @spec validate_plan(String.t()) :: {:ok, String.t()} | {:error, Zachaeus.error()}
  defp validate_plan(plan) when is_binary(plan) do
    cond do
      plan |> String.trim() |> String.length() <= 0 ->
        {:error, %Error{code: :plan_empty, message: "The given plan cannot be empty"}}

      Regex.match?(@license_separator_regex, plan) ->
        {:error, %Error{code: :plan_invalid, message: "The given plan contains a reserved character"}}

      true ->
        {:ok, plan}
    end
  end
  defp validate_plan(_invalid_plan), do: {:error, %Error{code: :plan_invalid, message: "The given plan is not a String"}}

  @spec validate_timerange(DateTime.t(), DateTime.t()) :: {:ok, DateTime.t(), DateTime.t()} | {:error, Zachaeus.error()}
  defp validate_timerange(%DateTime{} = valid_from, %DateTime{} = valid_until) do
    with {:ok, valid_from} <- shift_datetime(valid_from),
         {:ok, valid_until} <- shift_datetime(valid_until) do
      case DateTime.compare(valid_from, valid_until) do
        :gt -> {:error, %Error{code: :timerange_invalid, message: "The given timerange is invalid"}}
        _valid_timerange -> {:ok, valid_from, valid_until}
      end
    end
  end
  defp validate_timerange(_invalid_valid_from, _invalid_valid_until), do: {:error, %Error{code: :timerange_invalid, message: "The the given timerange needs a beginning and an ending DateTime"}}

  ## -- GENERAL HELPER FUNCTIONS
  @spec shift_datetime(DateTime.t()) :: {:ok, DateTime.t()} | {:error, Zachaeus.error()}
  defp shift_datetime(%DateTime{} = timestamp), do: DateTime.shift_zone(timestamp, @license_timezone)
  defp shift_datetime(_invalid_timestamp), do: {:error, %Error{code: :invalid_timestamp, message: "The timestamp cannot be shifted to UTC"}}
end
