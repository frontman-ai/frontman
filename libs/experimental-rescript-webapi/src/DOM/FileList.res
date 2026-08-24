/**
Returns the `WebApiFile` at the specified index.

`FileList` is not an array, so you need to iterate manually using `length` and `item`:

```rescript
let files = []
for i in 0 to fileList.length - 1 {
  files->Array.push(fileList->FileList.item(i))
}
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileList/item)
*/
@send
external item: (DomTypes.fileList, int) => FileTypes.file = "item"

@send
external itemNullable: (DomTypes.fileList, int) => Null.t<FileTypes.file> = "item"
