# Zachaeus
[![Build Status](https://travis-ci.org/railsmechanic/zachaeus.svg?branch=master)](https://travis-ci.org/railsmechanic/zachaeus)
[![Inline docs](http://inch-ci.org/github/railsmechanic/zachaeus.svg)](http://inch-ci.org/github/railsmechanic/zachaeus)

Zachaeus is a simple and easy to use licensing system for your Elixir application.
It's inspired by JWT, PASETO and other access control systems, which are using asymmetric signing.

A generated Zachaeus license contains all relevant data, which is essential for a simple licensing system.
Because of this nature, Zachaeus can be used without a database and integrates with Plug but can be used outside of it.
If you're implementing something which needs a licensing system, Zachaeus can work for you.

## Use cases
- Control access to web endpoints (Plug/Phoenix/<your framework>)
- Build software, where you want to issue licenses in order to control access and the functional scope
- Restrict access to any kind of software

## Features
- Generate public/private key(s) with a mix task
- Generate license(s) with a mix task and the given license data
- Contains an authentication plug which is compatible with web frameworks e.g. Phoenix
- No need to store the private key, used for license generation, on servers outside your organization
- A license contains all relevant data, therefore you don't even need a database

## Documentation
API documentation is available at [https://hexdocs.pm/zachaeus](https://hexdocs.pm/zachaeus)

## Installation
The package can be installed as Hex package:

Add Zachaeus to your application `mix.exs`

```elixir
defp deps do
  [{:zachaeus, "~> 1.0.0"}]
end
```

Run `mix deps.get` to fetch and install the package.

To leverage Zachaeus, you will need to generate a public/secret key pair by running `mix zachaeus.gen.keys`.
After running this mix task, you need to add the generated key pair to your configuration `config/config.exs`.

```elixir
config :zachaeus,
  public_key: "csKWI0t9mdPoyEWfXj4skhZpjaMp...",
  secret_key: "VkmBsZ5oklR8_MGk77AJUxDRpSqJL6449DTgK6y2f-hywpYjS32Z0..."
```

After adding the key pair to your configuration file, you are able to generate license(s) using the `mix zachaeus.gen.license` task.

```bash
$ mix zachaeus.gen.license --identifier user_1 --plan default_plan --valid-from 2020-01-01 --valid-until 2020-12-31
```

Congratulations! You have a working Zachaeus setup.

## Basics
Once Zachaeus was set up correctly, you can issue licenses using the `zachaeus.gen.license` mix task (as shown above) or with your own code. For issuing/signing licenses, Zachaeus requires either the configured secret key in your `config/config.exs` or a directly specified secret key.

```elixir
# Define a license with your specific license data
defined_license = %Zachaeus.License{
  identifier: "my_user_id_1",
  plan: "default",
  valid_from: ~U[2018-11-15 11:00:00Z],
  valid_until: ~U[2019-11-30 09:30:00Z]
}

# Sign the defined license using the configured secret key
signed_license = Zachaeus.sign(defined_license)

# Verify the signed license using the configured public key
{:ok, verified_license} = Zachaeus.verify(signed_license)

# Verify the signed license with the configured public key and validate the license in a single step
{:ok, 1123123} = Zachaeus.validate(signed_license)

# Get a boolean indicator, whether the license could be verified with the configured public key and is valid
Zachaeus.valid?(signed_license) # -> true
```

## Use with your web framework
Zachaeus comes with a default `EnsureAuthenticated` plug, which can be used with your plug compatible web framework e.g. Phoenix.

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug Zachaeus.Plug.EnsureAuthenticated
  end

  scope "/" do
    pipe_through :api
    # API related routes...
  end
end
```

If you need a custom behaviour, Zachaeus offers the ability to implement a fully customized plug on your own.
Just `use Zachaeus.Plug` in your module and implement the default and the `build_response` callback.

```elixir
defmodule CustomAuthentication do
  use Zachaeus.Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> fetch_license()
    |> verify_license()
    |> validate_license()
    |> build_response()
  end

  def build_response({conn, {:ok, _license}}), do: conn
  def build_response({conn, {:error, %Error{message: message}}}) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(:unauthorized, "Dude, you don't have a valid license!")
    |> halt()
  end
end
```

## Configuration
To keep Zachaeus configuration as simple as possible, it only needs a `secret_key` and/or a `public_key` (depending on your setup).
All configuration values may be provided in two ways.

1. Through your config file(s)
2. Passed directly to the function

If you don't want to store the configuration in the configuration file e.g. juggle with multiple keys or just to use keys stored within a database, all relevant functions like `sign/1`, `verify/1` etc. has a companion where the secret/public key can be specified directly.

```elixir
# Using the configured secret_key
signed_license = Zachaeus.sign(license)

# Using a specific secret_key
custom_secret_key = "thisisyourcustomsecretkey"
signed_license    = Zachaeus.sign(license, custom_secrect_key)
```

### Configuration values
The Zachaeus configuration is really simple, as it just has the following configuration values:

- `secret_key` - The key which is used to sign a license
- `public_key` - The key which is used to verify a license

_(The configuration values above are required for Zachaeus to work.)_

### Key security / Split configuration
Due to the nature of asymmetric cryptography, Zachaeus can be set up in a kind of _split configuration_.
With this type of configuration, you can keep your `secret_key` in a controlled and secure environment e.g. on your local computer and you just need to store the `public_key` outside of this secure environment e.g. on your web server.

When you use this setup, you can generate licenses (using the `secret_key`) from within your secure environment, issue the licenses to your customers and verifying them (using the `public_key`) in an unsecure environment.

#### License issuing system
It's just required to set the `secret_key` configuration value e.g. in your `config/config.exs`, but it wouldn't hurt either to set the `public_key` configuration value.

```elixir
config :zachaeus,
  public_key: "csKWI0t9mdPoyEWfXj4skhZpjaMp...",
  secret_key: "VkmBsZ5oklR8_MGk77AJUxDRpSqJL6449DTgK6y2f-hywpYjS32Z0..."
```

_&#9658; Please keep in mind, that the verification of license only works, when the `public_key` configuration value is set!_

#### License verifying system
It's strongly recommended to just set the `public_key` configuration value e.g. in your `config/config.exs` and not to set the `secret_key` configuration value.

```elixir
config :zachaeus,
  public_key: "csKWI0t9mdPoyEWfXj4skhZpjaMp..."
```

_&#9658; I recommend not to set the `secret_key` configuration value in a publicly available environment!_

## License
The MIT License (MIT). Please see [License File](LICENSE) for more information.
