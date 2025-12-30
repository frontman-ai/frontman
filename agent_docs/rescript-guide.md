# ReScript Patterns for Frontman

## Core Principles
- Never use mutable - use `ref` instead. Functional programming style.
- Never use `Obj.magic` unless you have explicit permission from the user
- Error handling: Use Result types
- File structure: Components: `Client__ComponentName.res`, Types: `Client__Types.res`, Main export: `Client.res`
- Use flat folder structure with ReScript namespacing convention

## React Components
- Use `@react.component` instead of `@genType` for React components
- Labelled Arguments: Use `~paramName=?` for optional parameters, `~paramName` for required
- Minimal Type Annotations: Only specify types when compilation requires it - let ReScript infer types
- JSX v4 Style: Use record syntax for styles with unquoted keys: `{padding: "20px", color: "white"}`

## Event Handling
- Event Property Access: Use `e->ReactEvent.Keyboard.shiftKey` not `ReactEvent.Keyboard.shiftKey`
- Function Call Syntax: Use `ReactEvent.Keyboard.preventDefault(e)` not `e->ReactEvent.Keyboard.preventDefault()`
- Complex Expressions: Wrap in parentheses: `!(e->ReactEvent.Keyboard.shiftKey)`
- Form Target Access: Use `target["value"]` instead of `target##value`

## JSX Patterns
- Text Content: Always use `React.string("text")` for text content
- Conditional Rendering: Use `condition ? <Component /> : React.null`
- Optional Props: Use `Option.mapOr(React.null, fn => <Component />)`
- Unused Parameters: Prefix with `_` (e.g., `~_onClearSelection=?`)

## Type System
- Variant Types: Use proper variant syntax: `type status = | Pending | Completed | Error`
- Module Prefixes: Use `Client__Types.Status` for accessing types from other modules
- Type Annotations: Add explicit types when needed: `~messages: option<array<Client__Types.chatMessage>>=?`

## String and Array Operations (ReScript v12+)
- String Concatenation: Use `++` operator: `"Hello " ++ name`
- String Interpolation: Use backticks: `` `Hello ${name}` ``
- Unicode Characters: Use backticks: `` `🎯 Click element` ``
- Array Operations: Use `Array.mapWithIndex`, `Array.join`, `Array.reduce`, `Array.filter`, `Array.slice` (not Belt.Array)
- Array.slice Parameters: Use `~start` and `~end` parameters: `Array.slice(~start=0, ~end=3)`
- Option Handling: Use `Option.getOr`, `Option.forEach`, `Option.mapOr` (not Belt.Option)
  - `getOr` instead of `getWithDefault`
  - `mapOr` instead of `mapWithDefault`
- String Operations: Use `String.length`, `String.trim`, `String.split` (not Js.String)

## React Hooks and Props
- React Hooks: Use `React.useState(() => initialValue)` and `React.useEffect(() => effect, deps)`
- useEffect Dependencies: CRITICAL - Modern ReScript uses `React.useEffect` (no numbers):
  - Single dep: Array `[dep]` - `React.useEffect(() => {...}, [dep])`
  - Multiple deps: Tuple `(dep1, dep2)` - `React.useEffect(() => {...}, (dep1, dep2))`
  - No deps: Empty array `[]` - `React.useEffect(() => {...}, [])`
  - NEVER use `React.useEffect1`, `React.useEffect2`, etc. in modern ReScript
- useEffect Return: Must return `option<unit => unit>` - use `None` for no cleanup, `Some(() => cleanup)` for cleanup
- Passing Optional Props: When passing optional props between components:
  - Parent: `~onReload: option<unit => unit>=?`
  - Child accepting it: `~onReload: option<unit => unit>` (no `=?`)
  - Pass directly: `onReload={onReload}` (don't unwrap)
- Optional Style Props: Handle with `style={style->Option.getOr({})}`
