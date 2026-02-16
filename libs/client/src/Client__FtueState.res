// FTUE (First-Time User Experience) state management via localStorage
//
// Tracks the user's FTUE progress:
//   - New: never visited before (key absent AND no other frontman keys)
//   - WelcomeShown: saw the welcome modal, hasn't completed signup celebration
//   - Completed: all FTUE flows finished
//
// Existing users who predate this feature are detected by the presence of other
// `frontman:*` localStorage keys (e.g. chatbox-width, selectedModel). When found,
// we auto-migrate them to Completed so they never see onboarding flows.

let storageKey = "frontman:ftue_state"

type t =
  | New
  | WelcomeShown
  | Completed

@val @scope("localStorage") external getItem: string => Nullable.t<string> = "getItem"
@val @scope("localStorage") external setItem: (string, string) => unit = "setItem"
@val @scope("localStorage") external localStorageKey: (int) => Nullable.t<string> = "key"
@val @scope("localStorage") external localStorageLength: int = "length"

// Check whether any other frontman:* localStorage key exists, indicating a returning user
let hasExistingFrontmanData = (): bool => {
  try {
    let len = localStorageLength
    let found = ref(false)
    for i in 0 to len - 1 {
      switch localStorageKey(i)->Nullable.toOption {
      | Some(k) =>
        switch k->String.startsWith("frontman:") && k !== storageKey {
        | true => found := true
        | false => ()
        }
      | None => ()
      }
    }
    found.contents
  } catch {
  | _ => false
  }
}

let get = (): t => {
  try {
    switch getItem(storageKey)->Nullable.toOption {
    | Some("welcome_shown") => WelcomeShown
    | Some("completed") => Completed
    | Some(_) | None =>
      // No FTUE key — check if user is truly new or an existing user who predates FTUE
      switch hasExistingFrontmanData() {
      | true =>
        // Auto-migrate existing user: write Completed so this check only runs once
        setItem(storageKey, "completed")
        Completed
      | false => New
      }
    }
  } catch {
  | _ => New
  }
}

let setWelcomeShown = () => {
  setItem(storageKey, "welcome_shown")
}

let setCompleted = () => {
  setItem(storageKey, "completed")
}
