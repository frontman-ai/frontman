type rec sourceLocation = {
  componentName: string,
  tagName: string,
  file: string,
  line: int,
  column: int,
  parent: option<sourceLocation>,
}
let sourceLocationSchema = S.recursive("SourceLocation", sourceLocationSchema => {
  S.object(s => {
    componentName: s.field("id", S.string),
    tagName: s.field("tagName", S.string),
    file: s.field("file", S.string),
    line: s.field("line", S.int),
    column: s.field("column", S.int),
    parent: s.field("parent", S.option(sourceLocationSchema)),
  })
})

@schema
type selectedElement = {
  selector: option<string>,
  screenshot: option<string>,
  sourceLocation: option<sourceLocation>,
}
@schema
type chat = {
  message: string,
  taskId: string,
  selectedElement: option<selectedElement>,
}
