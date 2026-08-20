type field = {
  name: string,
  value: string,
}

type t = array<field>

let make = (entries: array<(string, string)>): t =>
  entries->Array.map(((name, value)) => {name, value})

let fromFlatArray = (values: array<string>): t => {
  switch values->Array.length % 2 == 0 {
  | false => failwith("Node raw headers contained an unmatched field name")
  | true =>
    values
    ->Array.mapWithIndex((value, index) =>
      switch index % 2 == 0 {
      | true => Some({name: value, value: values[index + 1]->Option.getOrThrow})
      | false => None
      }
    )
    ->Array.filterMap(value => value)
  }
}

let values = (headers: t, ~name: string): array<string> => {
  let normalized = name->String.toLowerCase
  headers->Array.filterMap(field =>
    field.name->String.toLowerCase == normalized ? Some(field.value) : None
  )
}
