open DOMAPI

/**
Navigates to the given URL.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/assign)
*/
@send
external assign: (location, string) => unit = "assign"

/**
Removes the current page from the session history and navigates to the given URL.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/replace)
*/
@send
external replace: (location, string) => unit = "replace"

/**
Reloads the current page.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/reload)
*/
@send
external reload: location => unit = "reload"


/**
Returns the Location object's URL.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Location/href)
*/
@get
external href: location => string = "href"