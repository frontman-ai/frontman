module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

type tool = module(Tool.BrowserTool)

let browserTools = (~getPreviewDoc: unit => option<Tool.previewContext>): array<tool> => [
  FrontmanAstroBrowser__Tool__GetAstroAudit.make(~getPreviewDoc),
]
