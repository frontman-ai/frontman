include EventTarget.Impl({type t = CssFontLoadingTypes.fontFaceSet})

@send
external add: (
  CssFontLoadingTypes.fontFaceSet,
  CssFontLoadingTypes.fontFace,
) => CssFontLoadingTypes.fontFaceSet = "add"

@send
external delete: (CssFontLoadingTypes.fontFaceSet, CssFontLoadingTypes.fontFace) => bool = "delete"

@send
external clear: CssFontLoadingTypes.fontFaceSet => unit = "clear"

@send
external load: (
  CssFontLoadingTypes.fontFaceSet,
  ~font: string,
  ~text: string=?,
) => promise<array<CssFontLoadingTypes.fontFace>> = "load"

@send
external check: (CssFontLoadingTypes.fontFaceSet, ~font: string, ~text: string=?) => bool = "check"
