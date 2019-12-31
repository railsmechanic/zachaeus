defmodule Mix.Tasks.Zachaeus.Gen.License do
  @shortdoc "Generates a license with a configured secret key"

  @moduledoc """
  Generates a Zachaeus license.

      mix zachaeus.gen.license --identifier user_1 --plan default_plan --valid-from 2020-01-01 --valid-until 2020-12-31

  Generation of a license only works when a you have already generated a public/secret key pair
  with the `mix zachaeus.gen.keys` generator task and stored at least the secret key in your configuration
  according to the instructions. The default time zone in this task is _UTC_, which used for all license dates (valid from and valid until).

  The following named arguments are essential to generate a valid license.

  ## identifier
  By default, a license requires an identifier to differentiate users.
  To provide an user identifier,
  the `--identifier` option needs to be set. For example:

      mix zachaeus.gen.license --identifier user_1 ...

  ## plan
  By default, a license requires a plan name which e.g. allows you to enable special features for specific plans.
  To provide a plan identifier,
  the `--plan` option needs to be set. For example:

      mix zachaeus.gen.license --plan default_plan ...

  ## valid_from
  By default, a license requires a timestamp from which the licence is valid.
  To provide a starting time,
  the `--valid-from` option needs to be set. For example:

      mix zachaeus.gen.license --valid-from 2020-01-01 ...

  The provided date needs to be in ISO8601 format.
  This date will be converted to a 'beginning of day' timestamp in the _UTC_ time zone e.g. `2020-01-01T00:00:00Z`

  ## valid_until
  By default, a license requires a timestamp to which the licence is valid.
  To provide a ending time,
  the `--valid-until` option needs to be set. For example:

      mix zachaeus.gen.license --valid-until 2020-12-31 ...

  The provided date needs to be in ISO8601 format.
  This date will be converted to a 'end of day' timestamp in the _UTC_ time zone e.g. `2020-12-31T23:59:59Z`

  ## Support with generating the license
  This generator requires _ALL_ named options in order to being able generate a license.
  If you forget an option or the format of an input is invalid, the generator returns an error message.
  """
  alias Zachaeus.{Error, License}
  use Mix.Task

  ## -- MODULE CONSTANTS
  @switches [identifier: :string, plan: :string, valid_from: :string, valid_until: :string]

  ## -- TASK FUNCTIONS
  @doc false
  @impl Mix.Task
  def run(args) do
    with {:ok, _salty_started} <- Application.ensure_all_started(:salty),
         {:ok, arguments}      <- parse_options(args),
         {:ok, license}        <- build_license(arguments),
         {:ok, signed_license} <- sign_license(license)
    do
      Mix.shell().info("""
      Used the following data for generating the license:

        Identifier:  #{license.identifier}
        Plan:        #{license.plan}
        Valid from:  #{DateTime.to_iso8601(license.valid_from)}
        Valid until: #{DateTime.to_iso8601(license.valid_until)}

      The generated signed license which can be given e.g. to a customer:
      """)

      Mix.shell().info([
        :green,
        """
          #{signed_license}
        """
      ])
    else
      {:error, message} ->
        Mix.raise("""
        ERROR: #{message}

        The task expects, for example, the following arguments:
          mix zachaeus.gen.license --identifier user_1 --plan default_plan --valid-from 2020-01-01 --valid-until 2020-12-31
        """)
    end
  end

  ## -- HELPER FUNCTIONS
  @spec parse_options(arguments :: [binary()]) :: {:ok, Keyword.t()} | {:error, String.t()}
  defp parse_options(arguments) do
    case OptionParser.parse(arguments, strict: @switches) do
      {valid_args, _args, []} when valid_args != [] ->
        {:ok, valid_args}

      {_valid_args, _args, invalid_args} when invalid_args != [] ->
        {:error,
         "Unexpected argument(s) #{
           invalid_args |> Enum.map(fn {arg, _} -> arg end) |> Enum.join(" / ")
         }"}

      _unable_to_parse_arguments ->
        {:error, "Unable to parse arguments due to an invalid format"}
    end
  end

  @spec build_license(license_arguments :: Keyword.t()) :: {:ok, License.t()} | {:error, String.t()}
  defp build_license(
          identifier: identifier,
          plan: plan,
          valid_from: valid_from,
          valid_until: valid_until
        ) do
    with {:ok, valid_from}  <- parse_datetime(valid_from, :valid_from),
         {:ok, valid_until} <- parse_datetime(valid_until, :valid_until)
    do
      {:ok,
        %License{
          identifier: identifier,
          plan: plan,
          valid_from: valid_from,
          valid_until: valid_until
        }
      }
    end
  end

  defp build_license(_missing_license_data),
    do: {:error, "Unable to build license due to missing license data"}

  @spec sign_license(license :: License.t()) :: {:ok, License.signed()} | {:error, String.t()}
  defp sign_license(license) do
    case Zachaeus.sign(license) do
      {:ok, signed_license} ->
        {:ok, signed_license}

      {:error, %Error{message: message}} ->
        {:error, message}
    end
  end

  @spec parse_datetime(date :: String.t(), action :: :valid_from | :valid_until) :: {:ok, DateTime.t()} | {:error, String.t()}
  defp parse_datetime(date, :valid_from) when is_binary(date) do
    with {:ok, date} <- Date.from_iso8601(date) do
      {:ok,
        %DateTime{
          day: date.day,
          month: date.month,
          year: date.year,
          hour: 0,
          minute: 0,
          second: 0,
          microsecond: {0, 0},
          std_offset: 0,
          utc_offset: 0,
          zone_abbr: "UTC",
          time_zone: "Etc/UTC",
          calendar: Calendar.ISO
        }
      }
    else
      _unparsable_date ->
        {:error, "Unable to parse 'valid_from' date due to an invalid format"}
    end
  end
  defp parse_datetime(date, :valid_until) when is_binary(date) do
    with {:ok, date} <- Date.from_iso8601(date) do
      {:ok,
        %DateTime{
          day: date.day,
          month: date.month,
          year: date.year,
          hour: 23,
          minute: 59,
          second: 59,
          microsecond: {0, 0},
          std_offset: 0,
          utc_offset: 0,
          zone_abbr: "UTC",
          time_zone: "Etc/UTC",
          calendar: Calendar.ISO
        }
      }
    else
      _unparsable_date ->
        {:error, "Unable to parse 'valid_until' date due to an invalid format"}
    end
  end
  defp parse_datetime(_invalid_date, _invalid_action),
    do: {:error, "Unable to parse license validity period"}
end
