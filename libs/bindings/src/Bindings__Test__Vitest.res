@module("vitest") @scope("vi")
external waitFor: (unit => unit) => promise<unit> = "waitFor"

@module("vitest") external onTestFinished: (unit => unit) => unit = "onTestFinished"

@module("vitest") @scope("vi") external unstubAllGlobals: unit => unit = "unstubAllGlobals"
@module("vitest") @scope("vi") external stubGlobal: (string, 'a) => unit = "stubGlobal"
