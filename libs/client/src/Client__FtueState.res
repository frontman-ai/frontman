// FTUE (First-Time User Experience) state management via localStorage
//
// Tracks the user's FTUE progress:
//   - New: never visited before (key absent)
//   - WelcomeShown: saw the welcome modal, hasn't completed signup celebration
//   - Completed: all FTUE flows finished
//
// Existing users (who lack this key) are never shown FTUE flows.

let storageKey = "frontman:ftue_state"

type t =
  | New
  | WelcomeShown
  | Completed

@val @scope("localStorage") external getItem: string => Nullable.t<string> = "getItem"
@val @scope("localStorage") external setItem: (string, string) => unit = "setItem"

let get = (): t => {
  try {
    switch getItem(storageKey)->Nullable.toOption {
    | Some("welcome_shown") => WelcomeShown
    | Some("completed") => Completed
    | Some(_) | None => New
    }
  } catch {
  | _ => New
  }
}

let setWelcomeShown = () => {
  try {
    setItem(storageKey, "welcome_shown")
  } catch {
  | _ => ()
  }
}

let setCompleted = () => {
  try {
    setItem(storageKey, "completed")
  } catch {
  | _ => ()
  }
}
