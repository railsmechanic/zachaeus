defmodule Zachaeus.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Zachaeus.Plug

  alias Zachaeus.{Error, License}

  setup_all do
    {:ok, %{
      tampered_signed_license: "QrCTnY52fLzoWquad1ZtYB6EXqjpBRm9dTdGP7cDw2Vl3fuHvZdodW2q0EFNCwvBnY1hxmkrdRDZgHk-NLIEAHVzZXJfMXxkZWZhdWx0X3BsYW58MTU0NjMwMDgwMHw3MjU4MTE4Mzk4",
      expired_license: %License{
        identifier: "user_1",
        plan: "default_plan",
        valid_from: ~U[2018-01-01 00:00:00Z],
        valid_until: ~U[2018-12-31 23:59:59Z]
      },
      valid_license: %License{
        identifier: "user_1",
        plan: "default_plan",
        valid_from: ~U[2019-01-01 00:00:00Z],
        valid_until: ~U[2199-12-31 23:59:59Z]
      },
      predated_license: %License{
        identifier: "user_1",
        plan: "default_plan",
        valid_from: ~U[2199-01-01 00:00:00Z],
        valid_until: ~U[2199-12-31 23:59:59Z]
      },
    }}
  end

  setup do
    {:ok, %{conn: conn(:post, "/a/fancy/api/call")}}
  end

  describe "fetch_license/1" do
    test "extracts an expired signed license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.expired_license)
      conn = put_req_header(context.conn, "authorization", "Bearer #{signed_license}")

      assert {_conn, {:ok, signed_license}} = Zachaeus.Plug.fetch_license(conn)
      assert is_binary(signed_license)
      assert byte_size(signed_license) > 0
    end

    test "extracts a valid signed license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.valid_license)
      conn = put_req_header(context.conn, "authorization", "Bearer #{signed_license}")

      assert {_conn, {:ok, signed_license}} = Zachaeus.Plug.fetch_license(conn)
      assert is_binary(signed_license)
      assert byte_size(signed_license) > 0
    end

    test "extracts a predated signed license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.predated_license)
      conn = put_req_header(context.conn, "authorization", "Bearer #{signed_license}")

      assert {_conn, {:ok, signed_license}} = Zachaeus.Plug.fetch_license(conn)
      assert is_binary(signed_license)
      assert byte_size(signed_license) > 0
    end

    test "errors on a missing signed license", context do
      conn = put_req_header(context.conn, "authorization", "Bearer")
      assert {_conn, {:error, %Error{code: :extraction_failed, message: "Unable to extract license from the HTTP Authorization request header"}}} = Zachaeus.Plug.fetch_license(conn)
    end
  end

  describe "verify_license/1" do
    test "passes on a valid signed license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.valid_license)
      assert {conn, {:ok, license}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()

      assert match?(%License{}, license)
      assert conn.private[:zachaeus_identifier] == context.valid_license.identifier
      assert conn.private[:zachaeus_plan] == context.valid_license.plan
    end

    test "passes on an expired signed license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.expired_license)
      assert {conn, {:ok, license}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()

      assert match?(%License{}, license)
      assert conn.private[:zachaeus_identifier] == context.expired_license.identifier
      assert conn.private[:zachaeus_plan] == context.expired_license.plan
    end

    test "passes on a predated signed license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.predated_license)
      assert {conn, {:ok, license}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()

      assert match?(%License{}, license)
      assert conn.private[:zachaeus_identifier] == context.predated_license.identifier
      assert conn.private[:zachaeus_plan] == context.predated_license.plan
    end

    test "errors on an invalid signed license", context do
      assert {_conn, {:error, %Error{}}} =
        context.conn
        |> put_req_header("authorization", "Bearer absolutely_invalid_signed_license")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
    end

    test "errors on a tampered signed license", context do
      assert {conn, {:error, %Error{code: :license_tampered}}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{context.tampered_signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
    end

    test "errors on a non matching function call", context do
      assert {_conn, {:error, %Error{}}} = Zachaeus.Plug.verify_license({context.conn, 12345})
    end
  end

  describe "validate_license/1" do
    test "passes on a valid verified license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.valid_license)
      assert {conn, {:ok, license}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
        |> Zachaeus.Plug.validate_license()

      assert match?(%License{}, license)
      assert conn.private[:zachaeus_identifier] == context.valid_license.identifier
      assert conn.private[:zachaeus_plan] == context.valid_license.plan
      assert is_integer(conn.private[:zachaeus_remaining_seconds])
      assert conn.private[:zachaeus_remaining_seconds] > 0
    end

    test "errors on a verified but expired license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.expired_license)
      assert {_conn, {:error, %Zachaeus.Error{code: :license_expired}}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
        |> Zachaeus.Plug.validate_license()
    end

    test "errors on a verified but predated license", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.predated_license)
      assert {_conn, {:error, %Zachaeus.Error{code: :license_predated}}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
        |> Zachaeus.Plug.validate_license()
    end

    test "errors on an invalid signed license", context do
      assert {_conn, {:error, %Error{}}} =
        context.conn
        |> put_req_header("authorization", "Bearer absolutely_invalid_signed_license")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
        |> Zachaeus.Plug.validate_license()
    end

    test "errors on a non matching function call", context do
      assert {_conn, {:error, %Error{}}} = Zachaeus.Plug.verify_license({context.conn, 12345})
    end
  end

  describe "zachaeus_identifier/1" do
    test "extracts the zachaeus identifier in a connection", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.valid_license)
      assert {conn, {:ok, license}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
        |> Zachaeus.Plug.validate_license()

      assert Zachaeus.Plug.zachaeus_identifier(conn) == conn.private[:zachaeus_identifier]
      assert Zachaeus.Plug.zachaeus_identifier(conn) == context.valid_license.identifier
    end

    test "extracts nil for a non existant zachaeus identifier in a connection", context do
      assert Zachaeus.Plug.zachaeus_identifier(context.conn) == nil
    end
  end

  describe "zachaeus_plan/1" do
    test "extracts the zachaeus plan in a connection", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.valid_license)
      assert {conn, {:ok, license}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
        |> Zachaeus.Plug.validate_license()

      assert Zachaeus.Plug.zachaeus_plan(conn) == conn.private[:zachaeus_plan]
      assert Zachaeus.Plug.zachaeus_plan(conn) == context.valid_license.plan
    end

    test "extracts nil for a non existant zachaeus plan in a connection", context do
      assert Zachaeus.Plug.zachaeus_plan(context.conn) == nil
    end
  end

  describe "zachaeus_remaining_seconds/1" do
    test "extracts the zachaeus remaining seconds of a license in a connection", context do
      assert {:ok, signed_license} = Zachaeus.sign(context.valid_license)
      assert {conn, {:ok, license}} =
        context.conn
        |> put_req_header("authorization", "Bearer #{signed_license}")
        |> Zachaeus.Plug.fetch_license()
        |> Zachaeus.Plug.verify_license()
        |> Zachaeus.Plug.validate_license()

      assert Zachaeus.Plug.zachaeus_remaining_seconds(conn) == conn.private[:zachaeus_remaining_seconds]
      assert is_integer(Zachaeus.Plug.zachaeus_remaining_seconds(conn))
      assert Zachaeus.Plug.zachaeus_remaining_seconds(conn) > 0
    end

    test "extracts nil for a non existant zachaeus remaining seconds of a license in a connection", context do
      assert Zachaeus.Plug.zachaeus_remaining_seconds(context.conn) == nil
    end
  end
end
