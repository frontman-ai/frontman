open FileAPI
open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileList/item)
*/
@send
external item: (fileList, int) => file = "item"
