open Vitest

describe("tool consent", () => {
  testAsync("authorizes read-only tools once per browser session after listing them", async t => {
    let prompts = ref([])
    let authorize = Client__ToolConsent.make(
      ~confirm=prompt => {
        prompts := prompts.contents->Array.concat([prompt])
        true
      },
    )

    t
    ->expect(
      await authorize(
        ~name="read_file",
        ~arguments=None,
        ~readOnly=true,
        ~readOnlyTools=["search_files", "read_file"],
      ),
    )
    ->Expect.toBe(true)
    t
    ->expect(
      await authorize(
        ~name="search_files",
        ~arguments=None,
        ~readOnly=true,
        ~readOnlyTools=["search_files", "read_file"],
      ),
    )
    ->Expect.toBe(true)
    t->expect(prompts.contents->Array.length)->Expect.toBe(1)
    t
    ->expect(prompts.contents[0]->Option.getOrThrow->String.includes("read_file\nsearch_files"))
    ->Expect.toBe(true)
  })

  testAsync("prompts for every write with its tool name and inputs", async t => {
    let prompts = ref([])
    let authorize = Client__ToolConsent.make(
      ~confirm=prompt => {
        prompts := prompts.contents->Array.concat([prompt])
        true
      },
    )
    let arguments = Some(Dict.fromArray([("path", JSON.Encode.string("src/App.tsx"))]))

    for _ in 1 to 2 {
      t
      ->expect(
        await authorize(
          ~name="write_file",
          ~arguments,
          ~readOnly=false,
          ~readOnlyTools=["read_file"],
        ),
      )
      ->Expect.toBe(true)
    }

    t->expect(prompts.contents->Array.length)->Expect.toBe(2)
    let prompt = prompts.contents[0]->Option.getOrThrow
    t->expect(prompt->String.includes("write_file"))->Expect.toBe(true)
    t->expect(prompt->String.includes("src/App.tsx"))->Expect.toBe(true)
  })

  testAsync("does not retain denied read-only consent", async t => {
    let decisions = ref([false, true])
    let authorize = Client__ToolConsent.make(
      ~confirm=_ => {
        let decision = decisions.contents[0]->Option.getOrThrow
        decisions :=
          decisions.contents->Array.slice(~start=1, ~end=decisions.contents->Array.length)
        decision
      },
    )

    t
    ->expect(
      await authorize(
        ~name="read_file",
        ~arguments=None,
        ~readOnly=true,
        ~readOnlyTools=["read_file"],
      ),
    )
    ->Expect.toBe(false)
    t
    ->expect(
      await authorize(
        ~name="read_file",
        ~arguments=None,
        ~readOnly=true,
        ~readOnlyTools=["read_file"],
      ),
    )
    ->Expect.toBe(true)
  })
})
