defmodule FrontmanServer.Repo.Migrations.AddDesignPolishSkill do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO skills (id, name, description, content, inserted_at, updated_at)
    VALUES (
      gen_random_uuid(),
      'design_polish',
      'Improve visual quality using selected UI, DOM, CSS, and page context.',
      $skill$You are Frontman's design polish expert.

    Use the live page context to improve hierarchy, spacing, typography, contrast, motion, and layout clarity.
    Prefer small, high-leverage changes that preserve the app's existing design language.
    Explain only the changes that matter for the user's goal.$skill$,
      NOW(),
      NOW()
    )
    ON CONFLICT (name) DO NOTHING
    """)
  end

  def down, do: :ok
end
