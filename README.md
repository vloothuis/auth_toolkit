# AuthToolkit

A minimalist authentication toolkit for Phoenix applications that provides essential authentication features with intentionally limited configurability.

## Design Philosophy

AuthToolkit follows the principle of "do one thing well" by focusing exclusively on authentication:

- Minimal but complete authentication system
- Intentionally limited configurability to reduce implementation complexity
- Core authentication fields only (email + password)
- No support for additional user fields - implement these in your application
- Reasonable defaults over extensive configuration options

## Features

- User registration and login
- Email verification workflow
- Password reset functionality
- Rate limiting for security-sensitive operations
- Session and API token management
- Configurable email backend
- Configurable rate limiting backend

## User Model

The toolkit provides its own User model that handles authentication. Your application should reference this model through associations rather than extending it.

Example of connecting your application's user profile to AuthToolkit's user:

```elixir
defmodule MyApp.Accounts.Profile do
  use Ecto.Schema

  schema "profiles" do
    field :name, :string
    field :role, :string
    belongs_to :organization, MyApp.Organizations.Organization
    belongs_to :user, AuthToolkit.User
    
    timestamps()
  end
end

# In your context:
def create_profile_for_user(auth_user, attrs) do
  %Profile{}
  |> Profile.changeset(attrs)
  |> Ecto.Changeset.put_assoc(:user, auth_user)
  |> Repo.insert()
end
```

The AuthToolkit User model manages these fields:

- Email (required, unique)
- Password (required, hashed)
- Confirmed status

## Installation

Add `auth_toolkit` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:auth_toolkit, "~> 0.1.0"}
  ]
end
```

## Setup

### Required Configuration

1. Configure your endpoint to include peer data for rate limiting:

```elixir
# In your endpoint.ex
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [:peer_data, session: @session_options]]
```

2. Configure the repository and other settings in your `config.exs`:

```elixir
config :auth_toolkit,
  repo: YourApp.Repo,
  endpoint: YourAppWeb.Endpoint
```

3. Add the AuthToolkit routes to your router:

```elixir
# In lib/your_app_web/router.ex
defmodule YourAppWeb.Router do
  use Phoenix.Router

  require AuthToolkitWeb.Routes
  
  # ...your existing router configuration...

  # Add auth routes under "/auth" scope
  # You can customize the scope path by passing a :scope option
  AuthToolkitWeb.Routes.routes(scope: "/auth")
end
```

This will add the following routes:

- GET /auth/sign_up - User registration
- GET /auth/log_in - Login page
- POST /auth/log_in - Login action
- DELETE /auth/log_out - Logout action
- GET /auth/reset_password - Password reset
- GET /auth/account/settings/* - Account settings pages

4. Create a migration file to set up the required database tables:

Run the following shell command:

```mix ecto.gen.migration add_auth_toolkit_tables```

Now edit the file:

```elixir
# In priv/repo/migrations/YYYYMMDDHHMMSS_add_auth_toolkit_tables.exs
defmodule YourApp.Repo.Migrations.AddAuthToolkitTables do
  use Ecto.Migration

  def change do
    AuthToolkit.Migrations.up(version: 1)
  end
end
```

5. Configure the mailer and from email address:

```elixir
config :auth_toolkit, AuthToolkit.DefaultEmailBackend,
  mailer: MyApp.Mailer,  # Your application's Swoosh mailer
  from_email: "auth@yourapp.com"
```

Then run the migration:

```bash
mix ecto.migrate
```

This will create all necessary tables:

- `auth_toolkit_users` - Stores user accounts
- `auth_toolkit_confirmation_codes` - Manages email verification codes
- `auth_toolkit_user_tokens` - Handles session and API tokens

### Optional Configuration

The following configurations are optional and have sensible defaults:

4. Rate limiter (defaults to ETS-based implementation):

```elixir
config :auth_toolkit,
  rate_limiter: AuthToolkit.RateLimiter.ETS  # Optional - implement if you need custom rate limiting
```

## Rate Limiting

The toolkit includes built-in rate limiting for registration and login attempts:

- Registration: 10 attempts per 10 minutes
- Login: 5 attempts per 5 minutes

You can implement your own rate limiter by creating a module that implements the `AuthToolkit.RateLimiter` behaviour.

## Email Backend

Implement the `AuthToolkit.EmailBackend` behaviour to handle:

- Account confirmation emails
- Confirmation codes
- Password reset emails

## Usage Example

```elixir
# Registration with rate limiting
case AuthToolkit.register_user(user_params, remote_ip) do
  {:ok, user, confirmation_code} ->
    # Handle successful registration
  {:error, :rate_limit} ->
    # Handle rate limit error
  {:error, changeset} ->
    # Handle validation errors
end

# Authentication
user = AuthToolkit.get_user_by_email_and_password(email, password)

# Generate session token
token = AuthToolkit.generate_user_session_token(user)

# Generate API token
api_token = AuthToolkit.generate_user_api_token(user)
```

## Development

For local development and testing, run:

```bash
iex -S mix dev
```

This starts a development server with:

- Default configurations
- Mail preview at /dev/mailbox
- Stub rate limiter for testing
