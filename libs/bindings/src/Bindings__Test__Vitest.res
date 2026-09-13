type vi
type mock<'fn>
@val external vi: vi = "vi"
@send external automockModule: (vi, string) => unit = "mock"
@send external mocked: (vi, 'fn) => mock<'fn> = "mocked"
@send external implementation: (mock<'fn>, 'fn) => unit = "mockImplementation"
@send external stubGlobal: (vi, string, 'value) => unit = "stubGlobal"
@send external unstubAllGlobals: vi => unit = "unstubAllGlobals"
