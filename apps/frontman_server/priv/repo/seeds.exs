alias FrontmanServer.Accounts
alias FrontmanServer.Repo
alias FrontmanServer.Skills.Skill

official_skills_dir = Application.app_dir(:frontman_server, "priv/official_skills")

official_skills_dir
|> File.ls!()
|> Enum.filter(&String.ends_with?(&1, ".md"))
|> Enum.sort()
|> Enum.each(fn filename ->
  path = Path.join(official_skills_dir, filename)
  content = File.read!(path)

  ["", frontmatter, body] = String.split(content, "---", parts: 3)

  fields =
    frontmatter
    |> String.split("\n", trim: true)
    |> Map.new(fn line ->
      [key, value] = String.split(line, ":", parts: 2)
      {String.trim(key), String.trim(value)}
    end)

  %Skill{}
  |> Skill.changeset(%{
    name: Map.fetch!(fields, "name"),
    description: Map.fetch!(fields, "description"),
    content: String.trim(body)
  })
  |> Repo.insert!(
    on_conflict: {:replace, [:description, :content, :updated_at]},
    conflict_target: [:name]
  )
end)

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
