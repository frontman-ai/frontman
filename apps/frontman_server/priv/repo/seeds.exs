# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FrontmanServer.Repo.insert!(%FrontmanServer.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FrontmanServer.Accounts
alias FrontmanServer.Repo

# Create dev user (or find existing)
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

      # Auto-confirm the user
      user
      |> Accounts.User.confirm_changeset()
      |> Repo.update!()

    existing ->
      existing
  end

IO.puts("Dev user: #{user.email} (id: #{user.id})")
