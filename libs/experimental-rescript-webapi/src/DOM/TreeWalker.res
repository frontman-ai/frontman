@send
external parentNode: DomTypes.treeWalker => DomTypes.node = "parentNode"

@send
external firstChild: DomTypes.treeWalker => DomTypes.node = "firstChild"

@send
external lastChild: DomTypes.treeWalker => DomTypes.node = "lastChild"

@send
external previousSibling: DomTypes.treeWalker => DomTypes.node = "previousSibling"

@send
external nextSibling: DomTypes.treeWalker => DomTypes.node = "nextSibling"

@send
external previousNode: DomTypes.treeWalker => DomTypes.node = "previousNode"

@send
external nextNode: DomTypes.treeWalker => DomTypes.node = "nextNode"
