type shareData = {"title": string, "text": string, "url": string}

@get
external navigatorShareMethod: WebAPI.DomTypes.navigator => Nullable.t<shareData => promise<unit>> =
  "share"

@send
external shareWithNavigator: (WebAPI.DomTypes.navigator, shareData) => promise<unit> = "share"

let run = (~onShared, ~onCopied) => {
  let share = async () => {
    let navigator = WebAPI.Window.current->WebAPI.Window.navigator
    let text = "I just completed my first task with Frontman, an AI website editor for WordPress, Next.js, Astro, and Vite. Check it out:"
    switch navigator->navigatorShareMethod->Nullable.toOption {
    | Some(_) =>
      try {
        await navigator->shareWithNavigator({
          "title": "Frontman",
          "text": text,
          "url": "https://frontman.sh",
        })
        onShared()
      } catch {
      | exn
        if exn->JsExn.fromException->Option.map(FrontmanBindings.JsException.name) !=
          Some("AbortError") =>
        throw(exn)
      | _ => ()
      }
    | None =>
      await navigator
      ->WebAPI.Navigator.clipboard
      ->WebAPI.Clipboard.writeText(`${text} https://frontman.sh`)
      onCopied()
    }
  }
  share()->ignore
}
