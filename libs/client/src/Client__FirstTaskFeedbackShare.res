let text = "I just completed my first task with Frontman, an AI website editor for WordPress, Next.js, Astro, and Vite. Check it out:"
let shareData: FrontmanBindings.Navigator.shareData = {
  title: "Frontman",
  text,
  url: "https://frontman.sh",
}

let runWith = async (
  ~nativeShare,
  ~canNativeShare,
  ~writeText,
  ~onShared,
  ~onCopied,
  ~onFailed,
) => {
  let copy = async () => {
    try {
      await writeText(`${text} https://frontman.sh`)
      onCopied()
    } catch {
    | _ => onFailed()
    }
  }
  let canShare = switch (nativeShare, canNativeShare) {
  | (Some(_), Some(canShare)) =>
    try {
      canShare(shareData)
    } catch {
    | _ => false
    }
  | (Some(_), None) => true
  | (None, _) => false
  }
  switch canShare {
  | true =>
    let nativeShare = nativeShare->Option.getOrThrow
    try {
      await nativeShare(shareData)
      onShared()
    } catch {
    | exn
      if exn->JsExn.fromException->Option.map(FrontmanBindings.JsException.name) ==
        Some("AbortError") => ()
    | _ => await copy()
    }
  | false => await copy()
  }
}

let run = (~onShared, ~onCopied, ~onFailed) => {
  let navigator = WebAPI.Window.current->WebAPI.Window.navigator
  let nativeShare =
    navigator
    ->FrontmanBindings.Navigator.shareMethod
    ->Nullable.toOption
    ->Option.map(_ => shareData => navigator->FrontmanBindings.Navigator.share(shareData))
  let canNativeShare =
    navigator
    ->FrontmanBindings.Navigator.canShareMethod
    ->Nullable.toOption
    ->Option.map(_ => shareData => navigator->FrontmanBindings.Navigator.canShare(shareData))
  let writeText = text => navigator->WebAPI.Navigator.clipboard->WebAPI.Clipboard.writeText(text)
  runWith(~nativeShare, ~canNativeShare, ~writeText, ~onShared, ~onCopied, ~onFailed)->ignore
}
