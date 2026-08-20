type confirmation = string => bool

@val external browserConfirm: string => bool = "confirm"

let argumentsText = arguments =>
  arguments->Option.mapOr("{}", arguments => arguments->JSON.Encode.object->JSON.stringify)

let make = (~confirm: confirmation=browserConfirm) => {
  let readToolsAuthorized = ref(false)
  async (~name, ~arguments, ~readOnly, ~readOnlyTools) => {
    switch readOnly {
    | true if readToolsAuthorized.contents => true
    | true =>
      let names = readOnlyTools->Array.toSorted(String.compare)->Array.join("\n")
      let authorized = confirm(
        `Allow this Frontman session to use these read-only tools?\n\n${names}`,
      )
      switch authorized {
      | true => readToolsAuthorized := true
      | false => ()
      }
      authorized
    | false =>
      confirm(
        `Allow Frontman to run the write tool "${name}"?\n\nInputs:\n${argumentsText(arguments)}`,
      )
    }
  }
}
