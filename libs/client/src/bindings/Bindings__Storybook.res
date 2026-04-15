/**
 * ReScript bindings for Storybook 8.x
 * 
 * IMPORTANT: In .story.res files, NEVER use module aliases like:
 *   `module M = Some.Long.Path`
 * 
 * This compiles to `let M;` (undefined) which breaks Storybook's CSF parser.
 * Instead, use fully qualified names or the ArgsAdapter pattern below.
 * 
 * Usage:
 * ```rescript
 * open Bindings__Storybook
 * 
 * // Define args as simple types (strings, bools, numbers)
 * type args = { state: string, enabled: bool }
 * 
 * // Use ArgsAdapter to convert string args to proper types
 * let stateAdapter = ArgsAdapter.make([
 *   ("streaming", MyTypes.Streaming),
 *   ("done", MyTypes.Done),
 * ], ~fallback=MyTypes.Streaming)
 * 
 * let default: Meta.t<args> = {
 *   title: "Components/MyComponent",
 *   tags: ["autodocs"],
 *   render: args => <MyComponent state={stateAdapter.get(args.state)} />,
 * }
 * 
 * let primary: Story.t<args> = {
 *   args: { state: "streaming", enabled: true },
 * }
 * ```
 */
/** Meta configuration for a component's stories */
module Meta = {
  type t<'args> = {
    title: string,
    component?: React.component<'args>,
    tags?: array<string>,
    parameters?: Js.Dict.t<JSON.t>,
    argTypes?: Js.Dict.t<JSON.t>,
    args?: 'args,
    decorators?: array<(unit => React.element) => React.element>,
    render?: 'args => React.element,
  }
}

/** Individual story configuration */
module Story = {
  type playContext = {
    canvasElement: Dom.element,
    args: JSON.t,
  }

  type t<'args> = {
    name?: string,
    args?: 'args,
    parameters?: Js.Dict.t<JSON.t>,
    decorators?: array<(unit => React.element) => React.element>,
    render?: 'args => React.element,
    play?: playContext => promise<unit>,
  }
}

/** Helper to create a meta object */
let makeMeta = (
  ~title: string,
  ~component: React.component<'args>,
  ~tags: option<array<string>>=?,
  ~parameters: option<Js.Dict.t<JSON.t>>=?,
  ~argTypes: option<Js.Dict.t<JSON.t>>=?,
  ~args: option<'args>=?,
  ~decorators: option<array<(unit => React.element) => React.element>>=?,
): Meta.t<'args> => {
  {
    title,
    component,
    ?tags,
    ?parameters,
    ?argTypes,
    ?args,
    ?decorators,
  }
}

/** Helper to create a story object */
let makeStory = (
  ~name: option<string>=?,
  ~args: option<'args>=?,
  ~parameters: option<Js.Dict.t<JSON.t>>=?,
  ~decorators: option<array<(unit => React.element) => React.element>>=?,
  ~render: option<'args => React.element>=?,
  ~play: option<Story.playContext => promise<unit>>=?,
): Story.t<'args> => {
  {
    ?name,
    ?args,
    ?parameters,
    ?decorators,
    ?render,
    ?play,
  }
}

/** 
 * Create a simple render function for stories
 * This is useful when you need to customize rendering
 */
let withRender = (renderFn: 'args => React.element): Story.t<'args> => {
  {
    render: renderFn,
  }
}

/** Common story tags */
module Tags = {
  let autodocs = "autodocs"
  let docsPage = "docs-page"
}

/** Common decorator helpers */
module Decorators = {
  /** Wrap stories in a centered container */
  let centered = (storyFn: unit => React.element): React.element => {
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        minHeight: "100vh",
        padding: "2rem",
      }}
    >
      {storyFn()}
    </div>
  }

  /** Wrap stories with padding */
  let withPadding = (~padding: string="2rem", storyFn: unit => React.element): React.element => {
    <div style={{padding: padding}}> {storyFn()} </div>
  }

  /** Wrap stories in a dark background */
  let darkBackground = (storyFn: unit => React.element): React.element => {
    <div
      style={{
        backgroundColor: "#0a0a0f",
        minHeight: "100vh",
        padding: "2rem",
      }}
    >
      {storyFn()}
    </div>
  }
}

/**
 * ArgsAdapter - Convert string-based Storybook args to proper ReScript types
 * 
 * This solves the problem of needing module aliases in story files.
 * Instead of writing:
 *   `module M = Long.Path.To.Types` (BREAKS Storybook!)
 * 
 * Create an adapter:
 *   `let stateAdapter = ArgsAdapter.make([("streaming", Long.Path.To.Types.Streaming)], ~fallback=...)`
 * 
 * Then use it in render:
 *   `render: args => <Component state={stateAdapter.get(args.state)} />`
 */
module ArgsAdapter = {
  type t<'a> = {
    get: string => 'a,
    options: array<string>,
  }

  /** Create an adapter from string->value pairs with a fallback */
  let make = (mappings: array<(string, 'a)>, ~fallback: 'a): t<'a> => {
    {
      get: key =>
        mappings
        ->Array.find(((k, _)) => k == key)
        ->Option.map(((_, v)) => v)
        ->Option.getOr(fallback),
      options: mappings->Array.map(((key, _)) => key),
    }
  }

  /** Create an adapter from string->value pairs, using first as fallback */
  let fromPairs = (mappings: array<(string, 'a)>): t<'a> => {
    let fallback = mappings->Array.get(0)->Option.map(((_, v)) => v)
    switch fallback {
    | Some(fb) => make(mappings, ~fallback=fb)
    | None => {
        get: _ => Obj.magic(),
        options: [],
      }
    }
  }
}

/**
 * Browser testing utilities from @storybook/test
 * These provide interaction testing capabilities in Storybook
 */
module Browser = {
  /** Screen query result for finding elements */
  type screen

  /** Get a screen object scoped to an element */
  @module("@storybook/test")
  external within: Dom.element => screen = "within"

  /** Find element by text */
  @send
  external getByText: (screen, string) => Dom.element = "getByText"

  /** Find element by role */
  @send
  external getByRole: (screen, string) => Dom.element = "getByRole"

  /** Find element by role with options */
  @send
  external getByRoleWithName: (screen, string, {"name": string}) => Dom.element = "getByRole"

  /** Find element by test id */
  @send
  external getByTestId: (screen, string) => Dom.element = "getByTestId"

  /** Query element by text (returns null if not found) */
  @send
  external queryByText: (screen, string) => Nullable.t<Dom.element> = "queryByText"

  /** Find all elements by text */
  @send
  external getAllByText: (screen, string) => array<Dom.element> = "getAllByText"

  /** Async find element by text */
  @send
  external findByText: (screen, string) => promise<Dom.element> = "findByText"

  /** Expect result with matchers */
  type expectResult

  /** Expect assertion */
  @module("@storybook/test")
  external expect: 'a => expectResult = "expect"

  @send external toBeTruthy: expectResult => unit = "toBeTruthy"
  @send external toBeFalsy: expectResult => unit = "toBeFalsy"
  @send external toBeVisible: expectResult => unit = "toBeVisible"
  @send external toBeInTheDocument: expectResult => unit = "toBeInTheDocument"
  @send external toHaveTextContent: (expectResult, string) => unit = "toHaveTextContent"
  @send external toHaveClass: (expectResult, string) => unit = "toHaveClass"
  @send external toHaveAttribute: (expectResult, string, string) => unit = "toHaveAttribute"
  @send external toEqual: (expectResult, 'a) => unit = "toEqual"
  @send external toBe: (expectResult, 'a) => unit = "toBe"
  @send external not_: expectResult => expectResult = "not"

  /** User event for simulating interactions */
  module UserEvent = {
    type t

    @module("@storybook/test")
    external userEvent: t = "userEvent"

    @send external click: (t, Dom.element) => promise<unit> = "click"
    @send external dblClick: (t, Dom.element) => promise<unit> = "dblClick"
    @send external hover: (t, Dom.element) => promise<unit> = "hover"
    @send external unhover: (t, Dom.element) => promise<unit> = "unhover"
    @send external type_: (t, Dom.element, string) => promise<unit> = "type"
    @send external clear: (t, Dom.element) => promise<unit> = "clear"
    @send external tab: t => promise<unit> = "tab"
  }

  /** Wait for condition */
  @module("@storybook/test")
  external waitFor: (unit => unit) => promise<unit> = "waitFor"

  /** Async wait for condition */
  @module("@storybook/test")
  external waitForAsync: (unit => promise<unit>) => promise<unit> = "waitFor"
}
