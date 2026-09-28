@schema
type location = {
  componentName: option<string>,
  tagName: option<string>,
  file: string,
  line: int,
  column: int,
  componentProps: option<Dict.t<JSON.t>>,
}

@schema
type t = {
  definition: option<location>,
  invocations: array<location>,
}

let fromSourceLocation = (sourceLocation: Client__Types.SourceLocation.t): location => {
  componentName: sourceLocation.componentName,
  tagName: Some(sourceLocation.tagName),
  file: sourceLocation.file,
  line: sourceLocation.line,
  column: sourceLocation.column,
  componentProps: sourceLocation.componentProps,
}

let rec invocationsFromLegacyParents = (
  sourceLocation: option<Client__Types.SourceLocation.t>,
  invocations: array<location>,
): array<location> =>
  switch sourceLocation {
  | None => invocations
  | Some(sourceLocation) =>
    invocationsFromLegacyParents(
      sourceLocation.parent,
      Array.concat([fromSourceLocation(sourceLocation)], invocations),
    )
  }

let fromDefinition = (sourceLocation: Client__Types.SourceLocation.t): t => {
  definition: Some(fromSourceLocation(sourceLocation)),
  invocations: invocationsFromLegacyParents(sourceLocation.parent, []),
}

let rec locationChain = (locations: array<location>, index: int): option<
  Client__Types.SourceLocation.t,
> => {
  switch locations->Array.get(index) {
  | None => None
  | Some(location) =>
    Some({
      Client__Types.SourceLocation.componentName: location.componentName,
      tagName: location.tagName->Option.getOr("unknown"),
      file: location.file,
      line: location.line,
      column: location.column,
      parent: locationChain(locations, index + 1),
      componentProps: location.componentProps,
    })
  }
}

let toSourceLocation = (context: t): option<Client__Types.SourceLocation.t> => {
  let locations = switch context.definition {
  | Some(definition) => Array.concat([definition], context.invocations)
  | None => context.invocations
  }
  locationChain(locations, 0)
}

let hasReactLocation = (context: t): bool => {
  let isReactLocation = location => location.file->String.startsWith("about://React/")
  switch context.definition->Option.mapOr(false, isReactLocation) {
  | true => true
  | false => context.invocations->Array.some(isReactLocation)
  }
}

let stripFileQueries = (context: t): t => {
  let strip = location => {
    ...location,
    file: location.file->String.split("?")->Array.get(0)->Option.getOr(location.file),
  }
  {
    definition: context.definition->Option.map(strip),
    invocations: context.invocations->Array.map(strip),
  }
}
