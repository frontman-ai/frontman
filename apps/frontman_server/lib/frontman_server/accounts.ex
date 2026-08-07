defmodule FrontmanServer.Accounts do
  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Organizations],
    exports: [Scope, User, WorkOS.AuthError]

  alias FrontmanServer.Repo

  alias FrontmanServer.Accounts.{Scope, User, UserNotifier, UserToken, WorkOS}

  def scope_user(%Scope{} = scope), do: Scope.user(scope)

  def scope_user_id(scope) do
    scope
    |> scope_user()
    |> Map.fetch!(:id)
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def deliver_welcome_email(%User{} = user), do: UserNotifier.deliver_welcome(user)

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <- Repo.delete_all(UserToken.by_user_and_context(user.id, context)) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  def delete_user_session_token(token) do
    token
    |> UserToken.by_token_and_context("session")
    |> Repo.delete_all()

    :ok
  end

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        tokens_to_expire
        |> Enum.map(& &1.id)
        |> UserToken.by_ids()
        |> Repo.delete_all()

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  defdelegate get_oauth_authorization_url(provider, redirect_uri, state \\ nil),
    to: WorkOS,
    as: :get_authorization_url

  def authenticate_with_oauth(code, signup_framework \\ nil) do
    WorkOS.authenticate_with_code(code, signup_framework)
  end

  def authenticate_with_email_verification(
        code,
        pending_authentication_token,
        signup_framework \\ nil
      ) do
    WorkOS.authenticate_with_email_verification(
      code,
      pending_authentication_token,
      signup_framework
    )
  end

  defdelegate link_oauth_provider(user, code), to: WorkOS, as: :link_provider
  defdelegate unlink_oauth_provider(user, provider), to: WorkOS, as: :unlink_provider
  defdelegate list_user_identities(user), to: WorkOS, as: :list_identities
end
