/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/parentNode)
*/
@send
external parentNode: DomTypes.treeWalker => DomTypes.node = "parentNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/firstChild)
*/
@send
external firstChild: DomTypes.treeWalker => DomTypes.node = "firstChild"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/lastChild)
*/
@send
external lastChild: DomTypes.treeWalker => DomTypes.node = "lastChild"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/previousSibling)
*/
@send
external previousSibling: DomTypes.treeWalker => DomTypes.node = "previousSibling"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/nextSibling)
*/
@send
external nextSibling: DomTypes.treeWalker => DomTypes.node = "nextSibling"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/previousNode)
*/
@send
external previousNode: DomTypes.treeWalker => DomTypes.node = "previousNode"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/TreeWalker/nextNode)
*/
@send
external nextNode: DomTypes.treeWalker => DomTypes.node = "nextNode"
