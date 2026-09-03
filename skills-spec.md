# Skills Support Product Spec

## Product Thesis

Skills in Frontman should not feel like prompt packs. They should feel like Frontman becoming the right expert at the right moment.

Core delight:

> User asks normal goal. Frontman silently finds right capability, lightly reveals it, and produces better result than generic chat because it understands live app context.

Frontman advantage:

> Skills become more valuable because they run inside real page context: selected UI, DOM, CSS, routes, screenshots, logs, source mapping, and hot reload.

Generic agent skill systems are file/plugin management. Frontman skill system should be outcome routing inside live product surface.

## Primary Job To Be Done

When I am improving my page/app, I want Frontman to know which expert lens to apply, so I can get better design, SEO, copy, and product results without learning prompt engineering, skill names, or coding-agent workflows.

Sub-jobs:

- "Make this page better" -> Frontman routes to design/copy/SEO/conversion skills.
- "Improve this hero" -> Frontman uses selected element context and suggests relevant skills.
- "I want more capabilities" -> user opens Skill Library and sees globally available curated official skills.
- "I know what I want" -> user explicitly says `use SEO skill` or chooses skill chip.
- "I don't know what exists" -> Frontman exposes skills through contextual suggestions and goal search.

## Experience Principles

1. Skills mostly invisible by default.
User should not need to know what skill is. Skill should be internal routing layer.

2. Light visibility builds trust.
Show small chip: `Using Design Polish`, `Using SEO Auditor`, `Using Conversion Copy`. Not modal, not workflow blocker.

3. Discovery happens at moment of intent.
Best discovery surface is selected page/element plus user goal. "Good skills for this" beats generic marketplace browsing.

4. Library is curated, not chaotic.
Official skills first. Community later, if ever, behind quality filter.

5. Server-bundled skills are globally usable first.
No hunting markdown files. No copying prompts. No editing config. Available skills can be used immediately.

## Core UX Model

Three skill entry points:

- Automatic: Frontman detects likely skill from prompt/context.
Example: "make this section more premium" -> `Design Polish`.

- Explicit: User invokes skill directly.
Example: "use SEO auditor on this page."

- Library: User browses/searches available skills.
Example: Search "rank better" -> shows SEO-related official skills.

These should share same mental model: skills are expert lenses for goals.

## Suggested UI Shape

Compact skill chip in chat composer/result area:

`Using Design Polish`

Chip actions:

- click opens short explanation
- switch skill
- view related skills
- disable for this turn

Contextual suggestions near selection:

When user selects page/element, show 1-3 chips:

- `Polish design`
- `Improve SEO`
- `Rewrite for conversion`

Not "skills" first. Goals first. Skill name can appear beneath or after selection.

Skill Library:

- always reachable from small icon/menu
- search by goal, not skill filename
- curated presentation can be added later without storing category on `skills`
- all listed server-bundled skills are globally usable in MVP
- no install/default distinction in MVP

## Skill Library Positioning

Do not call it marketplace early. "Skill Library" or "Expert Library" better.

Marketplace implies abundance and quality variance. Library implies curation and trust.

Recommended framing:

> Official expert skills for improving live pages with Frontman.

Each skill card should answer:

- What user goal does this help with?
- When will Frontman use it automatically?
- What kind of results should user expect?
- What skill name can be referenced explicitly?

## Auto-Routing Behavior

Auto-routing is product direction, not backend MVP scope.

Do not introduce a backend skill router yet. The first backend implementation should only support explicit skill selection and task-history persistence. Routing can be designed later when the client-side surfaces and product interaction model are concrete.

Skill router should optimize for user intent, not exact keywords.

Signals:

- user prompt
- selected element/page
- current route/page type
- page metadata
- visible DOM/copy
- available server skills
- user explicitly named skill

Routing output should be explainable:

> "I'm using Design Polish because you selected a hero section and asked to make it feel more premium."

This creates delight: Frontman feels smart, not magical/opaque.

## Delight Moments

1. "I didn't know skills existed, but Frontman used right one."
User asks: "make this page better."
Frontman: `Using Design Polish + Conversion Copy`.
Result feels sharper.

2. "It knows what this page needs."
User selects hero.
Frontman suggests: `Improve headline`, `Polish layout`, `SEO check`.

3. "Using skills is easier than Cursor/Claude Code."
User opens library, sees available skills, and can use one immediately without install/configuration.

4. "I can find skills without knowing names."
Search: "get more signups" -> finds Conversion Copy, Landing Page Critic, CTA Optimizer.

## What Not To Build

Avoid:

- filesystem-first skill management
- giant marketplace grid as primary entry
- requiring users to know skill names
- making skill choice mandatory every turn
- config-heavy install or enablement flows
- exposing implementation concepts like MCP/OpenClaw unless in advanced view
- turning skills into reports-only UX
- hiding skill identity completely, because that kills trust and discoverability

## Product Architecture, Conceptually

Think of feature as four product layers:

- Server skill catalog: trusted official skills bundled with Frontman and available to every user.
- Skill router: decides best skill from prompt/context.
- Skill surfaces: chip, contextual suggestions, library/search.
- Task history: records which skill was used for each turn.

Most user value lives in router + surfaces, not skill format.

Backend MVP deliberately implements only the foundation:

- Server skill catalog stored in the database.
- Official skill seeds loaded by `priv/repo/seeds.exs`.
- Task history record for explicit skill use.
- LLM prompt reconstruction for selected skill use by storing a per-turn skill content snapshot and prepending it to that turn's user message.

Backend MVP does not implement skill library APIs, search APIs, automatic routing, or client-facing skill surfaces. Those should be dictated by the client experience later.

## Phoenix Schema And DB Contract

MVP stores only server-bundled official skills in the database. Future client-bundled skills should stay client-owned and client-resolved; the server database should not become the canonical store for client skill content. Treat namespace as implicit in the boundary field: server skills use server IDs, while future client skills pass the full skill payload for the current turn.

Use domain language instead of generic CRUD naming. The product noun is `Skill`, but the behavior is not "manage skill rows." The behavior is:

> Frontman catalogs skills and records when a task turn used one.

### `skills` table

This is the full MVP table. Do not add extra columns yet.

```elixir
create table(:skills, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :name, :string, null: false
  add :description, :text, null: false
  add :content, :text, null: false

  timestamps(type: :utc_datetime)
end

create unique_index(:skills, [:name])

create constraint(:skills, :skills_name_format,
  check: "name ~ '^[a-z0-9][a-z0-9_-]*$' AND name = lower(name)"
)
```

### `FrontmanServer.Skills.Skill` schema

```elixir
defmodule FrontmanServer.Skills.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @name_format ~r/^[a-z0-9][a-z0-9_-]*$/

  schema "skills" do
    field :name, :string
    field :description, :string
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:name, :description, :content])
    |> update_change(:name, &String.downcase/1)
    |> validate_required([:name, :description, :content])
    |> validate_format(:name, @name_format)
    |> validate_length(:description, min: 1, max: 200)
    |> validate_length(:content, min: 1)
    |> unique_constraint(:name)
    |> check_constraint(:name, name: :skills_name_format)
  end
end
```

### Field meanings

- `id`: database UUID. Used by `Skills.get_by_id(scope, id)` and `SkillUsed.skill_id` for server-bundled skills.
- `name`: machine-readable skill identifier. Always lowercase. Allowed characters: `a-z`, `0-9`, `_`, `-`. Must match `^[a-z0-9][a-z0-9_-]*$`.
- `description`: required human summary for catalog/search/UI. Maximum 200 characters.
- `content`: required skill instructions/body.

### Official skill seeds

Official server-bundled skills live in `priv/official_skills` only as seed input.

For server-bundled skills, the database is the source of truth after seeding. Runtime code for server skills must read from the `skills` table, not from markdown files. Seed loading should be idempotent: re-running seeds updates existing rows by `name` and does not create duplicates.

Invalid official skill seed files should fail loudly during seed load. Do not silently skip malformed files.

MVP seed loading should stay simple: keep markdown parsing and idempotent upsert logic directly in `priv/repo/seeds.exs` unless it becomes reused elsewhere. Do not add a separate loader module for one seed script.

Current seed markdown shape:

```md
---
name: design_polish
description: Improve visual quality using selected UI, DOM, CSS, and page context.
---

[skill.content]
```

### Validations

Application validations:

- `name` required.
- `name` is downcased before validation.
- `name` must match `^[a-z0-9][a-z0-9_-]*$`.
- `name` must be unique.
- `description` required and non-empty.
- `description` must be at most 200 characters.
- `content` required and non-empty.

Database validations:

- `name`, `description`, and `content` are `null: false`.
- `name` has unique index.
- `skills_name_format` check constraint enforces lowercase machine-name format even outside Ecto.

### Explicit exclusions

Do not add these tables in MVP:

- `skill_versions`
- `skill_installations`
- `skill_routing_events`
- organization-specific skill tables
- user-specific skill tables

Do not add these fields to `skills` in MVP:

- `slug`
- `category`
- `status`
- `title`
- `auto_route_enabled`
- `trigger_terms`
- `goal_examples`
- `instructions`
- `metadata`
- `provider`
- `version`
- `installed_at`
- `enabled`

`content` replaces the earlier `instructions` field name.

### Phoenix context API

```elixir
Skills.catalog(scope)
Skills.get_by_id(scope, id)
Skills.register(scope, attrs)
Skills.update(scope, skill, attrs)
```

Semantics:

- `catalog(scope)`: returns all globally usable server-bundled skills ordered by `name`.
- `get_by_id(scope, id)`: returns `{:ok, skill}` for a skill by database id or `{:error, :not_found}` if missing. Passing `nil` returns `{:ok, nil}` so callers can treat missing selection as normal no-skill state. Do not add pre-validation around ids here; let `Repo.get/2` own lookup semantics.
- `register(scope, attrs)`: registers a new server-bundled skill through `Skill.changeset/2`.
- `update(scope, skill, attrs)`: updates an existing skill through `Skill.changeset/2`.

Each method accepts `scope` first to match existing Phoenix context conventions and preserve future authorization shape. Scope is not used for filtering in MVP because all server-bundled skills are globally usable.

### Selected skill boundary contract

`TaskChannel` should translate ACP metadata casing into domain argument names before calling `Tasks.submit_user_message/2`, but it must not query skills or create task interactions directly.

MVP semantics:

- `_meta.selectedServerSkillId` references a server-bundled skill row.
- `TaskChannel` maps `_meta.selectedServerSkillId` to internal `:selected_server_skill_id` and does no skill lookup.
- `Tasks.submit_user_message/2` accepts optional `selected_server_skill_id` in its atom-keyed domain argument map.
- `Tasks` owns server skill lookup, `Interaction.SkillUsed` creation with a skill content snapshot, and interaction persistence.
- Missing server skill returns `{:error, :skill_not_found}` from `Tasks.submit_user_message/2`; `TaskChannel` maps it to ACP invalid params.

Current implementation shape:

```elixir
# TaskChannel boundary mapping only
selected_server_skill_id: meta["selectedServerSkillId"]

# Tasks context owns lookup
selected_server_skill_id = Map.get(arguments, :selected_server_skill_id)

with {:ok, user_message} <- Interaction.UserMessage.build(content_blocks, model),
     {:ok, selected_skill} <- Skills.get_by_id(scope, selected_server_skill_id),
     {:ok, {task_schema, turn_number}} <-
       insert_user_turn_for_locked_task(scope, task_id, user_message, selected_skill) do
  ...
else
  {:error, :not_found} -> {:error, :skill_not_found}
end

# Turn insertion records one ordered list
interactions =
  if selected_skill,
    do: [user_message, Interaction.SkillUsed.build(selected_skill)],
    else: [user_message]
```

This shape is intentional: one lookup, no channel query, no selected-skill wrapper, no `%Skills.Skill{}` crossing from channel into `Tasks`, and no validation ceremony after lookup.

Future client-skill semantics:

- Client-bundled skills should use a separate ACP metadata field, not `selectedServerSkillId`.
- The client should pass the full skill payload for the current turn to avoid a server/client round trip.
- Future client-bundled skills should use a separate domain argument that carries full client skill data. Do not force client skills through `selected_server_skill_id`, and do not store client skill bodies in the server skill catalog. If client skills are recorded in history later, snapshot their content in the task interaction for the selected turn, same as server skills.
- Add a dedicated selected-skill contract only when client payload support is implemented.

Lessons from implementation:

- Do not add a generic `ActiveSkill` layer before client-provided skills exist. Server-bundled MVP can use `Skills.Skill` directly inside `Tasks` after lookup.
- Do not make the channel resolve skills. It creates duplicate ceremony because `Tasks` still owns transaction safety and must decide whether to insert `SkillUsed`.
- Do not make `Tasks` accept `%Skills.Skill{}` from the channel, then revalidate it. Passing the server skill id is simpler and keeps lookup authority inside the context.
- Keep optional skill recording as data flow, not nested control flow. Build the interaction list for the turn as `[UserMessage]` or `[UserMessage, SkillUsed]`, then record the list in order. LLM serialization is responsible for folding `SkillUsed` back into the paired user message.
- Prefer one obvious branch over tiny helper functions for this flow. Helper names did not reduce concepts here; they hid simple optional persistence.
- Keep `TaskChannel` boring. Its job is protocol translation and error mapping, not domain lookup.
- Let the context own consistency. `Tasks.submit_user_message/2` must fetch skill before the transaction and return before inserting anything when the selected server skill is unknown.
- Keep no-skill as nil. `Skills.get_by_id(scope, nil) == {:ok, nil}` lets no-selection flow through the same path without extra branching in the channel.

## Task History Model

Do not create a separate routing events table for MVP.

Record skill usage as a task interaction:

- Add `SkillUsed` to `FrontmanServer.Tasks.Interaction`.
- Persist it through `interactions.type = :skill_used` and JSONB `data`.
- Keep it per-turn, not task-scoped, so it requires a `turn_number`.

`SkillUsed` fields:

- `id`
- `timestamp`
- `skill_id`
- `skill_name`
- `skill_content`

Store `skill_name` denormalized so old task history remains readable if the skill row changes later. Store `skill_content` as a snapshot so future conversation reconstruction uses the exact skill instructions that shaped the original assistant response, even if the catalog row changes later.

`skill_content` lives inside `interactions.data` JSONB. It does not require a database migration for the `interactions` table shape, but existing serialized `skill_used` rows without `skill_content` cannot reconstruct exact historical skill instructions. That is acceptable for current pre-MVP/dev data unless shipped persisted rows need explicit backfill.

### Recording selected skill use

When a turn explicitly uses a skill, insert `SkillUsed` in the same transaction as the `UserMessage` for that turn.

Rules:

- `Tasks.submit_user_message/2` resolves selected server skill before agent execution starts.
- If selected server skill id is unknown, return an error and insert no turn interactions.
- `UserMessage` and `SkillUsed` must share the same `turn_number`.
- Existing turns without a selected skill should continue unchanged.
- `UserMessage` must be inserted before `SkillUsed` in the same turn, so task history keeps natural turn order for UI/audit.
- `SkillUsed.skill_content` must snapshot the selected skill's `content` at submission time.
- The LLM serializer must treat `[UserMessage, SkillUsed]` in the same turn as one user message whose text is `[skill prompt section]\n\n[user message]`.

For MVP, `skill_id` records the server-bundled skill row. Future client skills may have no server id; do not use `skill_id` as the generic selected-skill contract outside `SkillUsed` persistence.

Boundary mapping:

- Client/ACP metadata uses camelCase `_meta.selectedServerSkillId` for server-bundled skills.
- `TaskChannel` maps that wire field to `:selected_server_skill_id`.
- `Tasks.submit_user_message/2` accepts atom-keyed domain arguments and should not know about ACP casing.
- Unknown selected server skill returns `{:error, :skill_not_found}` from `Tasks`.
- `TaskChannel` maps `:skill_not_found` to `JsonRpc.error_invalid_params()` with message `Selected skill not found`.
- `TaskChannel` should not call `Skills.get_by_id/2`; doing so duplicates domain responsibility and forces awkward revalidation in `Tasks`.

The `selectedServerSkillId` name is intentionally explicit. Future client-bundled skills should not pass an id that implies server persistence; they can pass the full client skill payload for the current turn through a separate metadata field when that feature is designed.

### LLM conversation serialization

`SkillUsed` is not a standalone user, assistant, or tool message. It is a per-turn prompt modifier for the user message that immediately precedes it in the same turn.

Serialize a skilled turn by folding `SkillUsed` into the paired `UserMessage`:

```elixir
Interaction.to_swarm_messages([user_message, skill_used])
# => [%SwarmAi.Message.User{content: [text("[skill section]\n\n[user message]")]}]
```

`SkillUsed` alone should still serialize to `[]`, because it has no user message to modify. `SkillUsed` must never emit assistant or tool messages.

Selected skill instructions should enter the model by prepending the active skill prompt section to that turn's user message. This must happen for both the immediate current turn and future conversation reconstruction when the user returns to a task and continues the conversation.

This design preserves causality in later turns: if turn 3 used `design_polish`, turn 4's reconstructed message chain still shows the exact skill instructions that shaped turn 3's assistant response.

Do not refetch historical skill content from the `skills` table during replay. Historical replay must use `SkillUsed.skill_content`, not the current catalog row, because official skill content can change after the turn was recorded.

Prompt section format:

```md
## Active Skill: design_polish

Use this expert lens for this turn.

[skill.content]
```

Use `skill.name` in the heading unless/until a separate display field exists. There is no `title` field in the MVP schema.

Do not apply a previous turn's skill to a later turn as active current-turn instructions unless the later turn also has its own `SkillUsed` interaction. Previous turns may still include their own scoped skill section as part of historical conversation reconstruction.

When serializing a turn with a selected skill, format the LLM user text as:

```md
## Active Skill: design_polish

Use this expert lens for this turn.

[skill.content snapshot]

[original user message and attached context]
```

`Execution.prompt_messages/2` must serialize ordered interactions with enough turn context to fold `[UserMessage, SkillUsed]` together. Serializing one database row at a time is insufficient because the `SkillUsed` row follows the `UserMessage` row and must prepend content to that message.

`SkillUsed` should also replay as an empty ACP history item for now. Client display of skill chips/history can be designed later.

## Backend MVP Implementation Plan

Build backend support first. No client work, no HTTP catalog API, no search endpoint, and no automatic skill router.

### Implementation status as of 2026-06-29

Completed:

- Added `skills` table migration with `id`, `name`, `description`, `content`, timestamps, unique `name`, and lowercase name check constraint.
- Added `FrontmanServer.Skills.Skill` schema and `FrontmanServer.Skills` context.
- Added `description` max length of 200 characters.
- Removed `title` completely from the backend MVP schema and task-history model.
- Added `priv/official_skills/design_polish.md` and inline seed parsing/upsert in `priv/repo/seeds.exs`.
- Added `Interaction.SkillUsed` with `id`, `timestamp`, `skill_id`, and `skill_name`.
- Added `:skill_used` to interaction type handling and ACP history replay as `[]`.
- Added optional explicit selected skill recording through `Tasks.submit_user_message/2`.
- Added channel boundary mapping from `_meta.selectedServerSkillId` to internal `:selected_server_skill_id`.
- Moved selected server skill lookup into `Tasks.submit_user_message/2` via `Skills.get_by_id/2`.
- Simplified turn insertion by recording `UserMessage` first and then optionally recording `SkillUsed` in the same transaction.
- `TaskChannel` no longer queries `Skills`; it only translates ACP casing into domain argument names.
- `Tasks.submit_user_message/2` maps `Skills.get_by_id/2` `{:error, :not_found}` to `{:error, :skill_not_found}`.
- `Skills.get_by_id/2` returns `{:ok, nil}` for nil ids so no selected skill stays a normal no-op path.
- Removed premature `ActiveSkill`/selected-skill wrapper ideas from MVP design.
- Removed channel-side `rescue Ecto.NoResultsError` and id pre-validation; `Repo.get/2` owns lookup behavior.
- Removed tiny selected-skill helper functions after they proved noisier than the direct flow.
- Removed nested optional-skill cases and tiny selected-skill wrappers in favor of direct optional interaction recording.
- Added `:skill_not_found` handling as ACP invalid params with message `Selected skill not found`.
- Added `skill_content` snapshot on `SkillUsed`.
- Updated `Interaction.to_swarm_messages/1` so `SkillUsed` prepends an active skill text part to the previous user message and emits nothing when unpaired.
- Updated `Execution.prompt_messages/2` to serialize ordered interactions by turn instead of one database row at a time.
- Verified selected skill content reaches the current LLM user turn, historical skilled turns replay with their stored skill snapshot, and unskilled later turns do not inherit previous skill instructions.
- Final backend verification passed with `make precommit` from `apps/frontman_server` (`mix precommit` is not defined in this project).

### Task 1: Add skills table

**Description:** Add DB persistence for globally usable server-bundled skills using the exact MVP contract in this spec.

**Acceptance criteria:**

- [x] `skills` table exists with `id`, `name`, `description`, `content`, timestamps.
- [x] `name`, `description`, and `content` are `null: false`.
- [x] `name` has a unique index.
- [x] DB check constraint `skills_name_format` enforces lowercase `^[a-z0-9][a-z0-9_-]*$`.

**Verification:**

- [x] `mix test test/frontman_server/skills_test.exs`
- [x] `mix compile --warnings-as-errors --all-warnings`

**Dependencies:** None

**Files likely touched:**

- `apps/frontman_server/priv/repo/migrations/*_create_skills.exs`

**Estimated scope:** Small

### Task 2: Add Skill schema and Skills context

**Description:** Add `FrontmanServer.Skills.Skill` and public `FrontmanServer.Skills` context API.

**Acceptance criteria:**

- [x] `Skill.changeset/2` downcases `name`.
- [x] Changeset validates required fields.
- [x] Changeset validates `name` format.
- [x] Changeset validates `description` max length of 200 characters.
- [x] Changeset enforces unique and check constraints.
- [x] `Skills.catalog(scope)` returns all skills ordered by `name`.
- [x] `Skills.get_by_id(scope, id)` fetches by DB id, returns `{:error, :not_found}` for missing ids, and returns `{:ok, nil}` when no id is selected.
- [x] `Skills.register(scope, attrs)` inserts through changeset.
- [x] `Skills.update(scope, skill, attrs)` updates through changeset.
- [x] `scope` arg is accepted first but unused for filtering in MVP.

**Verification:**

- [x] `mix test test/frontman_server/skills_test.exs`
- [x] `mix compile --warnings-as-errors --all-warnings`

**Dependencies:** Task 1

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/skills.ex`
- `apps/frontman_server/lib/frontman_server/skills/skill.ex`
- `apps/frontman_server/test/frontman_server/skills_test.exs`

**Estimated scope:** Medium

### Task 3: Add official skill seed loader

**Description:** Load official skill seed files from `priv/official_skills` into the database idempotently from `priv/repo/seeds.exs`.

**Acceptance criteria:**

- [x] Each official skill file maps deterministically to `name`, `description`, and `content`.
- [x] Missing or invalid fields fail loudly during seed load.
- [x] Re-running seeds does not duplicate skills.
- [x] Existing official skill rows update when seed file changes.
- [x] Runtime code reads skills from DB, not seed files.

**Verification:**

- [x] `mix run priv/repo/seeds.exs`

**Dependencies:** Task 2

**Files likely touched:**

- `apps/frontman_server/priv/official_skills/*.md`
- `apps/frontman_server/priv/repo/seeds.exs`

**Estimated scope:** Medium

### Task 4: Add SkillUsed interaction type

**Description:** Add `Interaction.SkillUsed` to the existing interaction model so selected skill use is persisted per turn.

**Acceptance criteria:**

- [x] `Interaction.SkillUsed` has fields `id`, `timestamp`, `skill_id`, `skill_name`.
- [x] `:skill_used` is added to `Interaction.type_values/0`.
- [x] `SkillUsed` is not task-scoped, so `turn_number` is required.
- [x] `Interaction.to_data_map/1` persists expected JSON data.
- [x] `InteractionSchema.to_struct/1` loads `SkillUsed`.
- [x] ACP history protocol has explicit implementation returning `[]`.

**Verification:**

- [x] `mix test test/frontman_server/tasks/interaction_test.exs`
- [x] `mix test test/protocols/acp_history_test.exs`
- [x] `mix test test/frontman_server/tasks_test.exs`

**Dependencies:** Task 2

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`
- `apps/frontman_server/lib/frontman_server/tasks/interaction_schema.ex`
- `apps/frontman_server/lib/frontman_server_web/protocols/acp_history_impl.ex`
- `apps/frontman_server/test/protocols/acp_history_test.exs`
- `apps/frontman_server/test/frontman_server/tasks/interaction_test.exs`

**Estimated scope:** Medium

Task 4 reflects the originally completed interaction type. Task 6 extends that type with `skill_content` after clarifying that LLM history must reconstruct the exact message chain for future turns.

### Task 5: Record selected server skill with user turn

**Description:** Extend task submission internals to accept a selected server skill id, resolve it inside `Tasks`, and insert `UserMessage` plus `SkillUsed` in the same transaction.

Current backend contract:

- ACP boundary: `_meta.selectedServerSkillId`.
- Channel/domain boundary: `:selected_server_skill_id`.
- Skills lookup: `Tasks.submit_user_message/2` calls `Skills.get_by_id/2`.
- No selection: `Skills.get_by_id(scope, nil) -> {:ok, nil}`.
- Unknown server skill: `Tasks.submit_user_message/2 -> {:error, :skill_not_found}`.
- Persistence: `insert_user_turn_if_idle/3` records `[UserMessage]` or `[UserMessage, SkillUsed]` in order.

**Acceptance criteria:**

- [x] `TaskChannel` maps `_meta.selectedServerSkillId` to `:selected_server_skill_id` before calling `Tasks.submit_user_message/2`.
- [x] `Tasks.submit_user_message/2` accepts optional `selected_server_skill_id` in input map.
- [x] `Tasks.submit_user_message/2` resolves selected server skill from DB before agent execution starts.
- [x] Missing selected server skill returns tagged error and inserts no user message.
- [x] `TaskChannel` maps `:skill_not_found` to ACP invalid params.
- [x] `UserMessage` and `SkillUsed` share same `turn_number`.
- [x] Existing calls without selected skill continue unchanged.
- [x] Turn still rejects when agent already running.
- [x] Turn insertion builds `[UserMessage]` or `[UserMessage, SkillUsed]` and records interactions in order.
- [x] No `ActiveSkill`, no `%Skills.Skill{}` crossing from channel to tasks, no channel skill lookup.

**Verification:**

- [x] `mix test test/frontman_server/tasks_test.exs`
- [x] `mix test test/frontman_server_web/channels/task_channel_test.exs`
- [x] `mix compile --warnings-as-errors --all-warnings`

**Dependencies:** Tasks 2 and 4

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/tasks.ex`
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`
- `apps/frontman_server/test/frontman_server_web/channels/task_channel_test.exs`

**Estimated scope:** Medium

### Task 6: Fold SkillUsed into paired user message

**Description:** Store the selected skill content snapshot on `SkillUsed` and serialize skilled turns by prepending the active skill section to the paired user message. `SkillUsed` must not become a standalone assistant, user, or tool message.

**Acceptance criteria:**

- [x] `Interaction.SkillUsed` has `skill_content`.
- [x] `Interaction.SkillUsed.build/1` snapshots `skill.content` into `skill_content`.
- [x] `Interaction.to_data_map/1` persists `skill_content` in `interactions.data`.
- [x] `InteractionSchema.to_struct/1` loads `skill_content` from persisted JSONB.
- [x] `Interaction.to_swarm_messages([user_message, skill_used])` emits exactly one user message.
- [x] The emitted user message prepends the deterministic `## Active Skill: ...` section before the original user message.
- [x] The emitted user message uses `skill_used.skill_content`, not a refetched `skills.content` value.
- [x] `Interaction.to_swarm_messages([skill_used])` returns `[]` because an unpaired skill row has no user message to modify.
- [x] `SkillUsed` never emits assistant or tool messages.
- [x] Existing turns without a selected skill serialize unchanged.

**Verification:**

- [x] `mix test test/frontman_server/tasks/interaction_test.exs`
- [x] `mix test test/frontman_server/tasks_test.exs`

**Dependencies:** Task 4

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/tasks/interaction.ex`
- `apps/frontman_server/test/frontman_server/tasks/interaction_test.exs`
- `apps/frontman_server/test/frontman_server/tasks_test.exs`

**Estimated scope:** Small

### Task 7: Reconstruct execution prompts with turn-level skill folding

**Description:** Update execution prompt reconstruction so stored interactions are serialized with enough turn context to fold each `[UserMessage, SkillUsed]` pair into one skilled user message. Do not add separate system prompt injection for selected skills; the selected skill content belongs with the user turn that selected it.

**Acceptance criteria:**

- [x] `Execution.prompt_messages/2` serializes ordered interactions by turn, not one database row at a time.
- [x] A current turn with `[UserMessage, SkillUsed]` sends one user message containing the skill section and original user prompt.
- [x] A later turn reconstructs previous skilled turns with their historical skill content snapshot.
- [x] Previous turn skills are scoped to their original user messages and do not become global current-turn system instructions.
- [x] `Execution.system_prompt/2` and `Prompts.build/1` do not receive selected skill data for MVP.
- [x] No duplicate skill instructions are emitted through both user message and system prompt.

**Verification:**

- [x] `mix test test/frontman_server/tasks/execution_test.exs`

**Dependencies:** Tasks 5 and 6

**Files likely touched:**

- `apps/frontman_server/lib/frontman_server/tasks/execution.ex`
- `apps/frontman_server/test/frontman_server/tasks/execution_test.exs`

**Estimated scope:** Medium

### Backend checkpoints

After Tasks 1-3:

- [x] Skill catalog can be persisted and seeded.
- [x] Re-running seeds is safe.
- [x] No API, router, or client code added.

After Tasks 4-5:

- [x] Skill usage is stored per turn.
- [x] Failed skill lookup leaves no partial interaction rows.
- [x] Existing task flows still pass.

After Tasks 6-7:

- [x] Current-turn skill affects the paired LLM user message.
- [x] Historical skilled turns reconstruct with their stored skill content snapshots.
- [x] Conversation message serialization emits no standalone `SkillUsed` assistant/tool/user messages.
- [x] ACP replay does not render skill use.

Final verification:

- [x] `mix test test/frontman_server/skills_test.exs`
- [x] `mix test test/frontman_server/tasks/interaction_test.exs`
- [x] `mix test test/frontman_server/tasks_test.exs`
- [x] `mix test test/frontman_server/tasks/execution_test.exs`
- [x] `mix test test/protocols/acp_history_test.exs`
- [x] `mix test test/frontman_server_web/channels/task_channel_test.exs`
- [x] `make precommit` from `apps/frontman_server`

## MVP

Build smallest delightful version:

- Bundled official skills seeded from `priv/official_skills` into the database.
- Server-bundled skills are globally usable; no install flow required.
- Explicit selected skill can be recorded for current turn.
- `SkillUsed` interaction records which skill was used during a turn and snapshots `skill_content`.
- Selected skill content is prepended to the LLM user message for that turn, including later conversation reconstruction.

Client-facing MVP, later:

- Auto-skill chip in chat: "Using X."
- User can override/switch skill for current turn.
- Contextual suggestions after element/page selection.
- Skill Library with goal search.

Skip for MVP:

- skill library API
- skill search API
- automatic skill router
- custom skill authoring
- per-user or per-organization installations
- skill versioning
- community marketplace
- ratings/reviews
- complex permissions
- paid skills
- deep skill analytics
- multi-skill orchestration UI

## North Star

Frontman skills should make user think:

> "I didn't have to know which expert to ask. Frontman knew, and result got better."
