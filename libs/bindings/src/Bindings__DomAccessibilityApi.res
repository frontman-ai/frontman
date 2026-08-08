@module("dom-accessibility-api")
external computeAccessibleName: WebAPI.DOMAPI.element => string = "computeAccessibleName"

@module("dom-accessibility-api")
external getRole: WebAPI.DOMAPI.element => Null.t<string> = "getRole"

@module("dom-accessibility-api")
external isInaccessible: WebAPI.DOMAPI.element => bool = "isInaccessible"
