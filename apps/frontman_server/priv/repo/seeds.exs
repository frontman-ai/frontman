alias FrontmanServer.Accounts
alias FrontmanServer.Repo

dev_email = "dev@frontman.local"

user =
  case Accounts.get_user_by_email(dev_email) do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{
          email: dev_email,
          name: "Dev User",
          password: "devpassword123!"
        })

      user
      |> Accounts.User.confirm_changeset()
      |> Repo.update!()

    existing ->
      existing
  end

IO.puts("Dev user: #{user.email} (id: #{user.id})")
