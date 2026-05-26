// Bindings for dom-accessibility-api
// Pure JS implementation of W3C accessible name/description computation
// https://github.com/eps1lon/dom-accessibility-api

// Compute the accessible name of an element per the W3C accname spec.
// Handles aria-label, aria-labelledby, <label>, alt, title, etc.
@module("dom-accessibility-api")
external computeAccessibleName: WebAPI.DOMAPI.element => string = "computeAccessibleName"

// Get the computed ARIA role of an element.
// Returns the explicit role attribute if set, otherwise the implicit role
// derived from the HTML element (e.g. <button> => "button", <a href> => "link").
// Returns null for elements with no role.
@module("dom-accessibility-api")
external getRole: WebAPI.DOMAPI.element => Null.t<string> = "getRole"

// Check whether an element is inaccessible (hidden from assistive technology).
// Checks display:none, visibility:hidden, aria-hidden="true", hidden attribute.
@module("dom-accessibility-api")
external isInaccessible: WebAPI.DOMAPI.element => bool = "isInaccessible"
