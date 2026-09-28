type annotation = {
  file: string,
  loc: Nullable.t<string>,
  componentProps?: Dict.t<JSON.t>,
  displayName?: string,
}

type annotationsApi = {
  get: WebAPI.DomTypes.element => Nullable.t<annotation>,
  getContentFile?: WebAPI.DomTypes.element => Nullable.t<string>,
  has: WebAPI.DomTypes.element => bool,
  size: unit => int,
  contentFile: Nullable.t<string>,
}

let getAnnotationsApi = (window: WebAPI.DomTypes.window): option<annotationsApi> => {
  let obj = window->Obj.magic
  let annotations: Nullable.t<annotationsApi> = obj["__frontman_annotations__"]
  annotations->Nullable.toOption
}
