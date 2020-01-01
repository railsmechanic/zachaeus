defmodule Zachaeus.ErrorTest do
  use ExUnit.Case, async: true
  doctest Zachaeus.Error

  test "for required fields" do
    error = %Zachaeus.Error{}
    assert Map.has_key?(error, :code)
    assert Map.has_key?(error, :message)
  end
end
