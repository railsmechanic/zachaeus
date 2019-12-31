defmodule Zachaeus.License do
  @moduledoc """
  The license contains all relevant data which is essential for a simple licensing system.
  Due to the nature of a license, it can be used without a database, if you simply want to verify the validity of a license.
  """

  alias Zachaeus.Error

  ## -- MODULE ATTRIBUTES
  @default_timezone "Etc/UTC"
  @separator_regex ~r/\|/

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
  Serializes a license into the defined string format.
  Before serializing, it validates the all license data.

  ## Examples
      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: 1, plan: "default", valid_from: "invalid datetime", valid_until: ~U[2019-11-15 11:00:00Z]})
      {:error, %Zachaeus.Error{code: :invalid_timestamp_type, message: "Unable to cast timestamp to DateTime"}}

      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: nil, plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:error, %Zachaeus.Error{code: :empty_identifier, message: "The given identifier cannot be empty"}}

      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: 1, plan: nil, valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:error, %Zachaeus.Error{code: :empty_plan, message: "The given plan cannot be empty"}}

      iex> Zachaeus.License.serialize(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]})
      {:ok, "my_user_id_1|default|1542279600|1573815600"}
  """
  @spec serialize(__MODULE__.t()) :: {:ok, __MODULE__.serialized()} | {:error, Zachaeus.Error.t()}
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
  def serialize(_invalid_license), do: {:error, %Error{code: :invalid_license_type, message: "Unable to serialize license due to an invalid type"}}

  @doc """
  Deserializes a license string into a license.
  After deserializing, it validates the all license data.

  ## Examples
      iex> Zachaeus.License.deserialize("my_user_id_1|default|invalid datetime|1573815600")
      {:error, %Zachaeus.Error{code: :invalid_timestamp_type, message: "Unable to cast timestamp to DateTime"}}

      iex> Zachaeus.License.deserialize(" |default|1542279600|1573815600")
      {:error, %Zachaeus.Error{code: :empty_identifier, message: "The given identifier cannot be empty"}}

      iex> Zachaeus.License.deserialize("my_user_id_1| |1542279600|1573815600")
      {:error, %Zachaeus.Error{code: :empty_plan, message: "The given plan cannot be empty"}}

      iex> Zachaeus.License.deserialize("absolutely_invalid_license_string")
      {:error, %Zachaeus.Error{code: :invalid_license_format, message: "Unable to deserialize license string due to an invalid format"}}

      iex> Zachaeus.License.deserialize("my_user_id_1|default|1542279600|1573815600")
      {:ok, %Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-15 11:00:00Z]}}

  """
  @spec deserialize(serialized_license :: __MODULE__.serialized()) :: {:ok, __MODULE__.t()} | {:error, Zachaeus.Error.t()}
  def deserialize(serialized_license) when is_binary(serialized_license) do
    case String.split(serialized_license, @separator_regex, trim: true) do
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

      _invalid_serialized_license_format ->
        {:error, %Error{code: :invalid_license_format, message: "Unable to deserialize license string due to an invalid format"}}
    end
  end
  def deserialize(_invalid_serialized_license), do: {:error, %Error{code: :invalid_license_type, message: "Unable to deserialize license due to an invalid type"}}

  @doc """
  Validates a license and checks whether its outdated.
  When the license is valid, it returns the remaining license time in seconds.

  ## Examples
      iex> Zachaeus.License.validate(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-30 09:50:00Z]})
      {:error, %Zachaeus.Error{code: :license_expired, message: "The license has expired"}}

      Zachaeus.License.validate(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2099-11-30 09:50:00Z]})
      {:ok, 12872893}
  """
  @spec validate(__MODULE__.t()) :: {:ok, Integer.t()} | {:error, Zachaeus.Error.t()}
  def validate(%__MODULE__{valid_from: valid_from, valid_until: valid_until}) do
    with {:ok, valid_from}          <- shift_datetime(valid_from),
         {:ok, valid_until}         <- shift_datetime(valid_until),
         {:ok, validation_datetime} <- shift_datetime(DateTime.utc_now())
    do
      case DateTime.compare(valid_from, validation_datetime) do
        from_timerange when from_timerange in [:eq, :lt] ->
          case DateTime.compare(valid_until, validation_datetime) do
            until_timerange when until_timerange in [:eq, :gt] ->
              {:ok, DateTime.diff(valid_until, validation_datetime)}
            _outdated_license ->
              {:error, %Error{code: :license_expired, message: "The license has expired"}}
          end
        _predated_license ->
          {:error, %Error{code: :license_predated, message: "The license is not yet valid"}}
      end
    end
  end
  def validate(_invalid_license), do: {:error, %Error{code: :invalid_license_type, message: "The given license is invalid"}}

  @doc """
  Validates a license and return a boolean to indicate that the license has expired.

  ## Examples
      iex> Zachaeus.License.valid?(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2099-11-30 09:50:00Z]})
      true

      iex> Zachaeus.License.valid?(%Zachaeus.License{identifier: "my_user_id_1", plan: "default", valid_from: ~U[2018-11-15 11:00:00Z], valid_until: ~U[2019-11-30 09:50:00Z]})
      false
  """
  @spec valid?(__MODULE__.t()) :: boolean()
  def valid?(%__MODULE__{} = license) do
    case validate(license) do
      {:ok, _remaining_time} -> true
      _invalid_license       -> false
    end
  end
  def valid?(_invalid_license), do: false

  ## -- CAST HELPER FUNCTIONS
  @spec cast_string(data :: String.t() | Integer.t() | Float.t() | Atom.t() | nil) :: {:ok, String.t()} | {:error, Zachaeus.Error.t()}
  defp cast_string(data) when is_binary(data), do: {:ok, String.trim(data)}
  defp cast_string(data) when is_number(data) or is_atom(data) or is_nil(data) do
    data
    |> to_string()
    |> cast_string()
  end
  defp cast_string(_invalid_data), do: {:error, %Error{code: :invalid_string_type, message: "Unable to cast data to String"}}

  @spec cast_datetime(timestamp :: DateTime.t() | Integer.t() | Float.t() | String.t()) :: {:ok, DateTime.t()} | {:error, Zachaeus.Error.t()}
  defp cast_datetime(%DateTime{} = timestamp), do: shift_datetime(timestamp)
  defp cast_datetime(timestamp) when is_integer(timestamp) do
    case DateTime.from_unix(timestamp) do
      {:ok, %DateTime{} = timestamp} ->
        shift_datetime(timestamp)

      _unable_to_cast_to_datetime ->
        {:error, %Error{code: :invalid_timestamp_type, message: "Unable to cast timestamp to DateTime"}}
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
        {:error, %Error{code: :invalid_timestamp_type, message: "Unable to cast timestamp to DateTime"}}
    end
  end
  defp cast_datetime(_invalid_timestamp), do: {:error, %Error{code: :invalid_timestamp_type, message: "Unable to cast timestamp to DateTime"}}

  ## -- VALIDATION HELPER FUNCTIONS
  @spec validate_identifier(identifier :: String.t()) :: {:ok, String.t()} | {:error, Zachaeus.Error.t()}
  defp validate_identifier(identifier) when is_binary(identifier) do
    cond do
      identifier |> String.trim() |> String.length() <= 0 ->
        {:error, %Error{code: :empty_identifier, message: "The given identifier cannot be empty"}}

      Regex.match?(@separator_regex, identifier) ->
        {:error, %Error{code: :invalid_identifer, message: "The given identifier contains a reserved character"}}

      true ->
        {:ok, identifier}
    end
  end
  defp validate_identifier(_invalid_identifier), do: {:error, %Error{code: :invalid_identifer, message: "The given identifier is not a String"}}

  @spec validate_plan(plan :: String.t()) :: {:ok, String.t()} | {:error, Zachaeus.Error.t()}
  defp validate_plan(plan) when is_binary(plan) do
    cond do
      plan |> String.trim() |> String.length() <= 0 ->
        {:error, %Error{code: :empty_plan, message: "The given plan cannot be empty"}}

      Regex.match?(@separator_regex, plan) ->
        {:error, %Error{code: :invalid_plan, message: "The given plan contains a reserved character"}}

      true ->
        {:ok, plan}
    end
  end
  defp validate_plan(_invalid_plan), do: {:error, %Error{code: :invalid_plan, message: "The given plan is not a String"}}

  @spec validate_timerange(DateTime.t(), DateTime.t()) :: {:ok, DateTime.t(), DateTime.t()} | {:error, Zachaeus.Error.t()}
  defp validate_timerange(%DateTime{} = valid_from, %DateTime{} = valid_until) do
    with {:ok, valid_from} <- shift_datetime(valid_from), {:ok, valid_until} <- shift_datetime(valid_until) do
      case DateTime.compare(valid_from, valid_until) do
        timerange when timerange in [:eg, :lt] ->
          {:ok, valid_from, valid_until}
        _invalid_timerange ->
          {:error, %Error{code: :invalid_timerange, message: "The given timerange is invalid"}}
      end
    end
  end
  defp validate_timerange(_invalid_valid_from, _invalid_valid_until), do: {:error, %Error{code: :invalid_timerange, message: "The the given timerange needs a beginning and an ending DateTime"}}

  ## -- GENERAL HELPER FUNCTIONS
  @spec shift_datetime(timestamp :: DateTime.t()) :: {:ok, DateTime.t()} | {:error, Zachaeus.Error.t()}
  defp shift_datetime(%DateTime{} = timestamp), do: DateTime.shift_zone(timestamp, @default_timezone)
  defp shift_datetime(_invalid_timestamp), do: {:error, %Error{code: :invalid_timestamp, message: "The timestamp cannot be shifted to UTC timezone"}}
end
