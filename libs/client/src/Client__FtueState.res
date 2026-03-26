// FTUE (First-Time User Experience) state management via localStorage
//
// Tracks the user's FTUE progress:
//   - New: never visited before (key absent AND no other frontman keys)
//   - WelcomeShown: saw the welcome modal, hasn't completed signup celebration
//   - Completed: all FTUE flows finished
//
// Existing users who predate this feature are detected by the presence of other
// `frontman:*` localStorage keys (e.g. chatbox-width, selectedModelValue). When found,
// we auto-migrate them to Completed so they never see onboarding flows.

let storageKey = "frontman:ftue_state"

type t =
  | New
  | WelcomeShown
  | Completed

type authBehavior =
  | ShowWelcomeModal
  | RedirectToLogin

// Check whether any other frontman:* localStorage key exists, indicating a returning user
let hasExistingFrontmanData = (): bool => {
  try {
    let len = FrontmanBindings.LocalStorage.length
    let found = ref(false)
    for i in 0 to len - 1 {
      switch FrontmanBindings.LocalStorage.key(i)->Nullable.toOption {
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
    switch FrontmanBindings.LocalStorage.getItem(storageKey)->Nullable.toOption {
    | Some("welcome_shown") => WelcomeShown
    | Some("completed") => Completed
    | Some(_) | None =>
      // No FTUE key — check if user is truly new or an existing user who predates FTUE
      switch hasExistingFrontmanData() {
      | true =>
        // Auto-migrate existing user: write Completed so this check only runs once
        FrontmanBindings.LocalStorage.setItem(storageKey, "completed")
        Completed
      | false => New
      }
    }
  } catch {
  | _ => New
  }
}

let getAuthBehavior = (): authBehavior => {
  switch get() {
  | New => ShowWelcomeModal
  | WelcomeShown | Completed => RedirectToLogin
  }
}

let setWelcomeShown = () => {
  FrontmanBindings.LocalStorage.setItem(storageKey, "welcome_shown")
}

let setCompleted = () => {
  FrontmanBindings.LocalStorage.setItem(storageKey, "completed")
}
