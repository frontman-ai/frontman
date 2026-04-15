open NavigationAPI

/**
Navigates backwards by one entry in the navigation history.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/back)
*/
@send
external back: (navigation, ~options: navigationNavigateOptions=?) => navigationResult = "back"

/**
Navigates forwards by one entry in the navigation history.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/forward)
*/
@send
external forward: (navigation, ~options: navigationNavigateOptions=?) => navigationResult =
  "forward"

/**
Returns an array of NavigationHistoryEntry objects representing all existing history entries.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/entries)
*/
@send
external entries: navigation => array<navigationHistoryEntry> = "entries"

/**
Navigates to a specific URL, updating any provided state in the history entries list.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/navigate)
*/
@send
external navigate: (navigation, string, ~options: navigationNavigateOptions=?) => navigationResult =
  "navigate"

/**
Reloads the current URL, updating any provided state in the history entries list.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/reload)
*/
@send
external reload: (navigation, ~options: navigationReloadOptions=?) => navigationResult = "reload"

/**
Navigates to a specific NavigationHistoryEntry identified by key.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/traverseTo)
*/
@send
external traverseTo: (
  navigation,
  string,
  ~options: navigationNavigateOptions=?,
) => navigationResult = "traverseTo"

/**
Updates the state of the currentEntry.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/updateCurrentEntry)
*/
@send
external updateCurrentEntry: (navigation, navigationUpdateCurrentEntryOptions) => unit =
  "updateCurrentEntry"

include EventTarget.Impl({type t = navigation})
