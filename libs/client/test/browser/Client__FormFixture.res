type t
@module("./formFixture.jsx") external create: string => promise<t> = "createFixture"
@get external doc: t => WebAPI.DomTypes.document = "doc"
@get external win: t => WebAPI.DomTypes.window = "win"
@get external state: t => string = "state"
@get external changes: t => int = "changes"
@get external focused: t => bool = "focused"
@get external value: t => string = "value"
@send external rowState: (t, int) => string = "rowState"
@send external rowValue: (t, int) => string = "rowValue"
@send external reload: t => promise<unit> = "reload"
@send external dispose: t => unit = "dispose"

module Task = Client__State__Types.Task
let originalState = StateStore.getState(Client__State__Store.store)

let preview = (~doc, ~win) => {
  let task = Task.makeNew(
    ~previewUrl="about:blank",
  )->Client__Task__Reducer.Lens.updatePreviewFrame(frame => {
    ...frame,
    contentDocument: Some(doc),
    contentWindow: Some(win),
  })
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    {...originalState, currentTask: Task.New(task)},
  )
}
let restore = () =>
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    originalState,
  )

let mounted = ref([])
let mount = async kind => {
  let fixture = await create(kind)
  mounted.contents->Array.push(fixture)->ignore
  preview(~doc=fixture->doc, ~win=fixture->win)
  fixture
}
let cleanup = () => {
  mounted.contents->Array.forEach(dispose)
  mounted := []
  restore()
}

module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
let execute = async (~name, json) => {
  module T = unpack(
    Client__ToolRegistry.forFramework(Wordpress).tools
    ->Array.find(tool => {
      module T = unpack(tool)
      T.name == name
    })
    ->Option.getOrThrow
  )
  let input = S.decodeOrThrow(json, ~from=S.jsonString, ~to=T.inputSchema)
  let result = await T.execute(input, ~taskId="form-acceptance", ~toolCallId="browser-test")
  result->S.decodeOrThrow(~from=MCP.CallToolResult.schema, ~to=S.json)
}
