defmodule Zachaeus.Error do
  @moduledoc """
  Represents the default error used in the Zachaeus package.
  The error has the ability to be customized.
  """
  defstruct [:code, :message]

  @typedoc """
  The default error used in Zachaeus.
  It contains a `code` part, which can be used as an indicator to customize the error message.
  """
  @type t() :: %__MODULE__{code: Atom.t(), message: String.t()}
end
