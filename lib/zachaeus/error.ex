defmodule Zachaeus.Error do
  @moduledoc """
  Represents an error throughout the zachaeus package.
  The error is built with customizability in mind.
  So you are able to match on a specific code and customize the default message.

  ## Example
      iex> case %Zachaeus.Error{code: :some_code, message: "Some default message"} do
      ...>   %Zachaeus.Error{code: :some_code} ->
      ...>     {:error, "My customized error message"}
      ...> end
      {:error, "My customized error message"}
  """
  defstruct [:code, :message]

  @typedoc """
  The default error used in zachaeus.
  It contains a `code`, which can be used as an indicator to be able to customize the default error `message`.
  """
  @type t() :: %__MODULE__{code: Atom.t(), message: String.t()}
end
