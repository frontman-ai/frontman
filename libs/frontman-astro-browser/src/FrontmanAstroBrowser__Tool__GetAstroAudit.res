// Browser tool that reads Astro's dev toolbar audit results.
//
// The Astro dev toolbar runs ~26 accessibility and performance checks.
// This tool traverses the toolbar's shadow DOM to extract those results
// and make them available to the agent.
//
// Uses factory pattern: make(~getPreviewDoc) => module(BrowserTool).
// The BrowserTool interface only passes (input, ~taskId, ~toolCallId) to
// execute, so there's no way to thread the preview doc accessor through
// the standard interface. The factory closes over getPreviewDoc at
// construction time.

S.enableJson()

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let name = Tool.ToolNames.getAstroAudit
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous

let description = `Read accessibility and performance audit results from Astro's dev toolbar.

Returns the current audit findings without parameters. Each entry includes
the rule code, category (a11y or performance), human-readable title/message/description,
and information about the offending element.

Returns an empty array with a message if:
- The preview iframe is not available
- The Astro dev toolbar is not present on the page
- The audit has not run yet`

@schema
type input = {placeholder?: bool}

@schema
type elementInfo = {
  tagName: string,
  selector: string,
  textSnippet: string,
}

@schema
type auditEntry = {
  code: string,
  category: string,
  title: string,
  message: string,
  description: string,
  element: elementInfo,
}

@schema
type output = {
  audits: array<auditEntry>,
  message: option<string>,
}

let emptyResult = (~message): Tool.toolResult<output> => Ok({audits: [], message: Some(message)})

// Typed externals for Astro dev toolbar custom element APIs.
// The audit data lives behind two shadow DOM layers, all mode: "open".

// Resolve a rule field that can be string | (Element) => string.
// Uses runtime typeof to call function-valued rule fields.
let resolveRuleField = (field: 'a, element: WebAPI.DOMAPI.element): string => {
  switch typeof(field) {
  | #function =>
    let fn: WebAPI.DOMAPI.element => string = Obj.magic(field)
    fn(element)
  | _ => Obj.magic(field)
  }
}

// Get .audits property from the audit window custom element.
// Returns array of {auditedElement, rule} objects.
type auditRule = {
  code: string,
  title: unknown,
  message: unknown,
  description: unknown,
}

type rawAudit = {
  auditedElement: WebAPI.DOMAPI.element,
  rule: auditRule,
}

@get external getAudits: WebAPI.DOMAPI.element => Nullable.t<array<rawAudit>> = "audits"

let categoryFromCode = (code: string): string =>
  switch code->String.startsWith("perf-") {
  | true => "performance"
  | false => "a11y"
  }

let elementSelector = (el: WebAPI.DOMAPI.element): string => {
  let tag = el.tagName->String.toLowerCase
  let cls = el->WebAPI.Element.getAttribute("class")->Null.toOption->Option.getOr("")->String.trim
  switch cls {
  | "" => tag
  | c => `${tag}.${c->String.split(" ")->Array.filter(s => s !== "")->Array.join(".")}`
  }
}

let elementTextSnippet = (el: WebAPI.DOMAPI.element): string => {
  let text =
    (el :> WebAPI.DOMAPI.node)
    ->WebAPI.Node.textContent
    ->Null.toOption
    ->Option.getOr("")
    ->String.trim
  switch text->String.length > 80 {
  | true => text->String.slice(~start=0, ~end=80) ++ "..."
  | false => text
  }
}

let convertAudit = (raw: rawAudit): auditEntry => {
  let el = raw.auditedElement
  {
    code: raw.rule.code,
    category: categoryFromCode(raw.rule.code),
    title: resolveRuleField(raw.rule.title, el),
    message: resolveRuleField(raw.rule.message, el),
    description: resolveRuleField(raw.rule.description, el),
    element: {
      tagName: el.tagName->String.toLowerCase,
      selector: elementSelector(el),
      textSnippet: elementTextSnippet(el),
    },
  }
}

let extractAudits = (doc: WebAPI.DOMAPI.document): Tool.toolResult<output> => {
  // Layer 1: find astro-dev-toolbar
  let toolbar = doc->WebAPI.Document.querySelector("astro-dev-toolbar")->Null.toOption
  switch toolbar {
  | None => emptyResult(~message="Astro dev toolbar not found. Is this an Astro dev page?")
  | Some(toolbar) =>
    // Layer 2: toolbar's shadow root → audit app canvas
    let toolbarShadow = toolbar.shadowRoot->Null.toOption
    switch toolbarShadow {
    | None => emptyResult(~message="Astro dev toolbar shadow root not accessible")
    | Some(shadowRoot) =>
      let auditCanvas =
        shadowRoot
        ->WebAPI.ShadowRoot.querySelector(`astro-dev-toolbar-app-canvas[data-app-id="astro:audit"]`)
        ->Null.toOption
      switch auditCanvas {
      | None => emptyResult(~message="Astro audit app not found in dev toolbar")
      | Some(canvas) =>
        // Layer 3: audit canvas shadow root → audit window
        let canvasShadow = canvas.shadowRoot->Null.toOption
        switch canvasShadow {
        | None => emptyResult(~message="Astro audit canvas shadow root not accessible")
        | Some(canvasShadowRoot) =>
          let auditWindow =
            canvasShadowRoot
            ->WebAPI.ShadowRoot.querySelector("astro-dev-toolbar-audit-window")
            ->Null.toOption
          switch auditWindow {
          | None => emptyResult(~message="Astro audit window element not found")
          | Some(auditEl) =>
            let rawAudits = getAudits(auditEl)->Nullable.toOption->Option.getOr([])
            switch rawAudits->Array.length {
            | 0 => emptyResult(~message="No audit results found. The audit may not have run yet.")
            | _ => Ok({audits: rawAudits->Array.map(convertAudit), message: None})
            }
          }
        }
      }
    }
  }
}

let make = (~getPreviewDoc: unit => option<Tool.previewContext>): module(Tool.BrowserTool) => {
  module(
    {
      let name = name
      let visibleToAgent = visibleToAgent
      let executionMode = executionMode
      let description = description
      type input = input
      type output = output
      let inputSchema = inputSchema
      let outputSchema = outputSchema
      let execute = async (_input, ~taskId as _, ~toolCallId as _) =>
        switch getPreviewDoc() {
        | None => emptyResult(~message="Preview iframe is not available")
        | Some({doc}) => extractAudits(doc)
        }
    }
  )
}
