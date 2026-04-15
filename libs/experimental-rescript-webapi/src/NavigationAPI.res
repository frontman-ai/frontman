@@warning("-30")

open EventAPI

type navigationType =
  | @as("push") Push
  | @as("reload") Reload
  | @as("replace") Replace
  | @as("traverse") Traverse

type navigationHistoryBehavior =
  | @as("auto") Auto
  | @as("push") Push
  | @as("replace") Replace

/**
The Navigation interface of the Navigation API allows control over all navigation actions for the current window in one central place.
[See Navigation on MDN](https://developer.mozilla.org/docs/Web/API/Navigation)
*/
@editor.completeFrom(Navigation)
type rec navigation = {
  ...eventTarget,
  /**
    Returns true if it is possible to navigate backwards in the navigation history.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/canGoBack)
    */
  canGoBack: bool,
  /**
    Returns true if it is possible to navigate forwards in the navigation history.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/canGoForward)
    */
  canGoForward: bool,
  /**
    Returns a NavigationHistoryEntry object representing the location the user is currently navigated to.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/currentEntry)
    */
  currentEntry: Null.t<navigationHistoryEntry>,
  /**
    Returns a NavigationTransition object representing the status of an in-progress navigation.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Navigation/transition)
    */
  transition: Null.t<navigationTransition>,
}

/**
Represents a single navigation history entry.
[See NavigationHistoryEntry on MDN](https://developer.mozilla.org/docs/Web/API/NavigationHistoryEntry)
*/
@editor.completeFrom(NavigationHistoryEntry) and navigationHistoryEntry = {
  ...eventTarget,
  /**
    Returns the key of the history entry.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationHistoryEntry/key)
    */
  key: string,
  /**
    Returns the id of the history entry.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationHistoryEntry/id)
    */
  id: string,
  /**
    Returns the URL of the history entry.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationHistoryEntry/url)
    */
  url: Null.t<string>,
  /**
    Returns the index of the history entry.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationHistoryEntry/index)
    */
  index: int,
  /**
    Returns true if the history entry is the same document as the current document.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationHistoryEntry/sameDocument)
    */
  sameDocument: bool,
}

/**
Represents an ongoing navigation.
[See NavigationTransition on MDN](https://developer.mozilla.org/docs/Web/API/NavigationTransition)
*/
@editor.completeFrom(NavigationTransition) and navigationTransition = {
  /**
    Returns the type of the navigation.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationTransition/navigationType)
    */
  navigationType: navigationType,
  /**
    Returns the NavigationHistoryEntry being navigated from.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationTransition/from)
    */
  from: navigationHistoryEntry,
  /**
    Returns a promise that fulfills when the navigation completes.
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/NavigationTransition/finished)
    */
  finished: Promise.t<unit>,
}

/**
Represents the result of a navigation operation.
*/
type navigationResult = {
  /**
    A promise that fulfills when the navigation commits.
    */
  committed: Promise.t<navigationHistoryEntry>,
  /**
    A promise that fulfills when the navigation completes.
    */
  finished: Promise.t<navigationHistoryEntry>,
}

type navigationNavigateOptions = {
  mutable state?: JSON.t,
  mutable history?: navigationHistoryBehavior,
  mutable info?: JSON.t,
}

type navigationReloadOptions = {
  mutable state?: JSON.t,
  mutable info?: JSON.t,
}

type navigationUpdateCurrentEntryOptions = {mutable state: JSON.t}
