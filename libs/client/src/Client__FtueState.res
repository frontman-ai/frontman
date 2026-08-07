let storageKey = "frontman:ftue_state"

type t =
  | New
  | WelcomeShown
  | Completed

type authBehavior =
  | ShowWelcomeModal
  | RedirectToLogin

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
      switch hasExistingFrontmanData() {
      | true =>
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
