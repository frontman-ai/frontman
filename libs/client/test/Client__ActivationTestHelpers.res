@module("vitest") @scope("vi") external stubGlobal: (string, 'a) => unit = "stubGlobal"
@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"

let setup = () => {
  stubGlobal("__frontmanRuntime", {"framework": "vite"})
  stubGlobal("heap", {"track": (_: string, _: JSON.t) => ()})
}
