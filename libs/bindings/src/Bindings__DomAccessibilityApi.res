@module("dom-accessibility-api")
external computeAccessibleName: WebAPI.DomTypes.element => string = "computeAccessibleName"

@module("dom-accessibility-api")
external getRole: WebAPI.DomTypes.element => Null.t<string> = "getRole"

@module("dom-accessibility-api")
external isInaccessible: WebAPI.DomTypes.element => bool = "isInaccessible"
