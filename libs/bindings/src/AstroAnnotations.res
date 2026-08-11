type annotation = {
  file: string,
  loc: Nullable.t<string>,
  componentProps?: Dict.t<JSON.t>,
  displayName?: string,
}

type annotationsApi = {
  get: WebAPI.DOMAPI.element => Nullable.t<annotation>,
  getContentFile?: WebAPI.DOMAPI.element => Nullable.t<string>,
  has: WebAPI.DOMAPI.element => bool,
  size: unit => int,
  contentFile: Nullable.t<string>,
}

let getAnnotationsApi = (window: WebAPI.DOMAPI.window): option<annotationsApi> => {
  let obj = window->Obj.magic
  let annotations: Nullable.t<annotationsApi> = obj["__frontman_annotations__"]
  annotations->Nullable.toOption
}
