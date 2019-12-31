defmodule Zachaeus.Plug.EnsureAuthenticatedTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Zachaeus.License
  alias Zachaeus.Plug.EnsureAuthenticated

  setup_all do
    {:ok, %{
      predated_license: %License{
        identifier: "user_1",
        plan: "default_plan",
        valid_from: ~U[2199-01-01 00:00:00Z],
        valid_until: ~U[2199-12-31 23:59:59Z]
      },
      expired_license: %License{
        identifier: "user_1",
        plan: "default_plan",
        valid_from: ~U[2018-01-01 00:00:00Z],
        valid_until: ~U[2018-12-31 23:59:59Z]
      },
    }}
  end

  setup do
    {:ok, %{conn: conn(:post, "/a/fancy/api/call")}}
  end

  describe "errors on" do
    test "missing authorization header", context do
      conn =
        context.conn
        |> EnsureAuthenticated.call([])

      assert Jason.decode!(conn.resp_body) == %{"error" => "Unable to extract license from the HTTP Authorization request header"}
      assert conn.status == 401
      assert conn.halted
    end

    test "empty authorization header", context do
      conn =
        context.conn
        |> put_req_header("authorization", "")
        |> EnsureAuthenticated.call([])

      assert Jason.decode!(conn.resp_body) == %{"error" => "Unable to extract license from the HTTP Authorization request header"}
      assert conn.status == 401
      assert conn.halted
    end

    test "predated license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.predated_license)
      conn =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> EnsureAuthenticated.call([])

      assert Jason.decode!(conn.resp_body) == %{"error" => "The license is not yet valid"}
      assert conn.status == 401
      assert conn.halted
    end

    test "expired license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.expired_license)
      conn =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> EnsureAuthenticated.call([])

      assert Jason.decode!(conn.resp_body) == %{"error" => "The license has expired"}
      assert conn.status == 401
      assert conn.halted
    end
  end

  describe "passes on" do
    test "valid license", context do
      assert {:ok, signed_license} =
        Zachaeus.sign(%License{
          identifier: "user_1",
          plan: "default_plan",
          valid_from: ~U[2019-01-01 00:00:00Z],
          valid_until: ~U[2199-12-31 23:59:59Z]
        })

      conn =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> EnsureAuthenticated.call([])

      refute conn.halted
    end
  end
end
