defmodule EWalletAPI.V1.AuthController do
  use EWalletAPI, :controller
  import EWalletAPI.V1.ErrorHandler
  alias EWalletAPI.V1.ClientAuthPlug
  alias EWalletAPI.V1.EndUserAuthenticator
  alias EWalletDB.{AuthToken, User}

  @doc """
  Logins the user.

  This function is used when the eWallet is setup as a standalone solution,
  allowing users to log in without an integration with the provider's server.
  """
  def login(conn, attrs) do
    with email when is_binary(email) <- attrs["email"] || {:error, :missing_email},
         password when is_binary(password) <- attrs["password"] || {:error, :missing_password},
         conn <- EndUserAuthenticator.authenticate(conn, email, password),
         true <- conn.assigns.authenticated || {:error, :invalid_login_credentials},
         true <-
           User.get_status(conn.assigns.end_user) == :active || {:error, :email_not_verified},
         {:ok, auth_token} <- AuthToken.generate(conn.assigns.end_user, :ewallet_api) do
      render(conn, :auth_token, %{auth_token: auth_token})
    else
      {:error, code} ->
        handle_error(conn, code)
    end
  end

  @doc """
  Invalidates the authentication token used in this request.

  Note that this function can logout the user sessions generated by both
  the Admin API and the eWallet API.
  """
  def logout(conn, _attrs) do
    conn
    |> ClientAuthPlug.expire_token()
    |> render(:empty_response, %{})
  end
end
