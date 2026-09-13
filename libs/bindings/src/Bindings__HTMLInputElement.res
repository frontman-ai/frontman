type prototype
type setter
type descriptor = {set: setter}
@val @scope("HTMLInputElement") external prototype: prototype = "prototype"
@val @scope("Object")
external valueDescriptor: (prototype, @as("value") _) => Nullable.t<descriptor> =
  "getOwnPropertyDescriptor"
@send
external callSetter: (setter, WebAPI.DomTypes.htmlInputElement, string) => unit = "call"

let setNativeValue = (input, value) => {
  let descriptor = valueDescriptor(prototype)->Nullable.getOrThrow
  descriptor.set->callSetter(input, value)
}
