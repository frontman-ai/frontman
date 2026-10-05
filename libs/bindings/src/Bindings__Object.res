@get external completedFileChanges: 'record => Nullable.t<'value> = "completedFileChanges"

type prototype
type descriptor<'target, 'value>
type setter<'target, 'value>

@get external prototype: 'constructor => prototype = "prototype"
@scope("Object") @val
external getOwnPropertyDescriptor: (prototype, string) => option<descriptor<'target, 'value>> =
  "getOwnPropertyDescriptor"
@get external setter: descriptor<'target, 'value> => option<setter<'target, 'value>> = "set"
@send external callSetter: (setter<'target, 'value>, 'target, 'value) => unit = "call"
