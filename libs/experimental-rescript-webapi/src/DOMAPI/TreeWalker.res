open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/parentNode)
*/
@send
external parentNode: treeWalker => node = "parentNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/firstChild)
*/
@send
external firstChild: treeWalker => node = "firstChild"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/lastChild)
*/
@send
external lastChild: treeWalker => node = "lastChild"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/previousSibling)
*/
@send
external previousSibling: treeWalker => node = "previousSibling"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/nextSibling)
*/
@send
external nextSibling: treeWalker => node = "nextSibling"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/previousNode)
*/
@send
external previousNode: treeWalker => node = "previousNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/nextNode)
*/
@send
external nextNode: treeWalker => node = "nextNode"
