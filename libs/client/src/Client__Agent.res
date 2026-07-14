module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

type t = {
  name: string,
  displayName: string,
  description: string,
  color: string,
}

@schema
type metadata = {
  @as("frontman.dev/agentColor")
  color: string,
  @as("frontman.dev/agentName")
  name: string,
}

@schema
type messageMetadata = {
  @as("frontman.dev/agentId")
  agentId: string,
}

let hexColor = RegExp.fromString("^#[0-9A-Fa-f]{6}$")

let messageAgentId = meta => {
  let parsed =
    meta
    ->Option.getOrThrow(~message="User message agent metadata is required")
    ->S.parseOrThrow(~to=messageMetadataSchema)
  parsed.agentId
}

let options = (configOptions: array<ACP.sessionConfigOption>) => {
  let config =
    configOptions
    ->Array.find(option =>
      switch option {
      | ACP.SelectConfigOption({id: "agent", category: Some(Mode)}) => true
      | _ => false
      }
    )
    ->Option.getOrThrow(~message="Agent config option is required")

  switch config {
  | ACP.SelectConfigOption({options: Ungrouped(options)}) => options
  | ACP.SelectConfigOption({options: Grouped(groups)}) =>
    groups->Array.flatMap(group => group.options)
  }
}

let findOrThrow = (configOptions: array<ACP.sessionConfigOption>, agentId: string): t => {
  let option =
    options(configOptions)
    ->Array.find(option => option.value == agentId)
    ->Option.getOrThrow(~message=`Unknown agent: ${agentId}`)
  let metadata =
    option._meta
    ->Option.getOrThrow(~message=`Agent ${agentId} is missing metadata`)
    ->S.parseOrThrow(~to=metadataSchema)

  switch hexColor->RegExp.test(metadata.color) {
  | true => ()
  | false => failwith(`Agent ${agentId} color must use #RRGGBB format`)
  }

  {
    name: metadata.name,
    displayName: option.name,
    description: option.description->Option.getOrThrow(
      ~message=`Agent ${agentId} description is required`,
    ),
    color: metadata.color,
  }
}
