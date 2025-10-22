# ReScript React Component Conversion Patterns

## Core Patterns
1. **Use `@react.component`** instead of `@genType` for React components
2. **Labelled Arguments**: Use `~paramName=?` syntax for optional parameters, `~paramName` for required
3. **Minimal Type Annotations**: Only specify types when compilation requires it - let ReScript infer types
4. **JSX v4 Style**: Use record syntax for styles with unquoted keys: `{padding: "20px", color: "white"}`

## Event Handling
5. **Event Property Access**: Use `e->ReactEvent.Keyboard.shiftKey` not `ReactEvent.Keyboard.shiftKey`
6. **Function Call Syntax**: Use `ReactEvent.Keyboard.preventDefault(e)` not `e->ReactEvent.Keyboard.preventDefault()`
7. **Complex Expressions**: Wrap in parentheses: `!(e->ReactEvent.Keyboard.shiftKey)`
8. **Form Target Access**: Use `target["value"]` instead of `target##value` for JavaScript object properties

## JSX Patterns
9. **Text Content**: Always use `React.string("text")` for text content
10. **Conditional Rendering**: Use `condition ? <Component /> : React.null`
11. **Optional Props**: Use `Belt.Option.mapWithDefault(React.null, fn => <Component />)`
12. **Unused Parameters**: Prefix with `_` (e.g., `~_onClearSelection=?`)

## Type System
13. **Variant Types**: Use proper variant syntax: `type status = | Pending | Completed | Error`
14. **Module Prefixes**: Use `Client__Types.Status` for accessing types from other modules
15. **Type Annotations**: Add explicit types when needed: `~messages: option<array<Client__Types.chatMessage>>=?`

## String and Array Operations (ReScript v12+)
16. **String Concatenation**: Use `++` operator: `"Hello " ++ name`
17. **String Interpolation**: Use backticks for Unicode support and interpolation: `` `Hello ${name}` ``
18. **Array Operations**: Use `Array.mapWithIndex`, `Array.join` (not Belt.Array)
19. **Option Handling**: Use `Option.getOr`, `Option.forEach`, `Option.mapOr` (not Belt.Option)
    - `getOr` instead of `getWithDefault`
    - `mapOr` instead of `mapWithDefault`
20. **String Operations**: Use `String.length`, `String.trim`, `String.split` (not Js.String)
21. **Array Functions**: Use `Array.reduce`, `Array.filter`, `Array.slice` (not Belt.Array)
22. **Array.slice Parameters**: Use `~start` and `~end` parameters: `Array.slice(~start=0, ~end=3)`

## Common Pitfalls
23. **Unicode Characters**: Use backticks for Unicode support: `` `🎯 Click element` `` instead of `"🎯 Click element"`
24. **String Interpolation**: Use backticks for interpolation: `` `Hello ${name}` `` instead of `"Hello " ++ name`
25. **JSX Syntax**: Ensure proper closing tags and use `React.string()` for all text content
26. **Boolean Expressions**: Wrap complex boolean expressions in parentheses for proper evaluation
27. **Passing Optional Props**: When passing optional props between components:
    - Parent: `~onReload: option<unit => unit>=?`
    - Child accepting it: `~onReload: option<unit => unit>` (no `=?`)
    - Pass directly: `onReload={onReload}` (don't unwrap)
28. **React Hooks**: Use `React.useState(() => initialValue)` and `React.useEffect1(() => effect, [deps])`
29. **useEffect Return**: Must return `option<unit => unit>` - use `None` for no cleanup, `Some(() => cleanup)` for cleanup
30. **Component Props with Underscores**: Some components use `_propName` for unused props - match the exact prop names
31. **Variant Types in Switch**: Use `switch` expressions for variant types: `switch variant { | Case1 => ... | Case2 => ... }`
32. **Optional Style Props**: Handle optional style props with `style={style->Option.getOr({})}`
33. **Module Exports**: Update `Client.res` to export new components without `@genType` unless needed

## File Structure
- Components: `Client__ComponentName.res`
- Types: `Client__Types.res` 
- Main export: `Client.res` with module exports
- Use flat folder structure with ReScript namespacing convention

## Example Component Structure
```rescript
@react.component
let make = (
  ~title=?,
  ~subtitle=?,
  ~onClick=?,
) => {
  let title = title->Belt.Option.getWithDefault("Default Title")
  
  <div
    style={
      padding: "20px",
      backgroundColor: "#111827",
    }>
    <h2>
      {React.string(title)}
    </h2>
    {onClick->Belt.Option.mapWithDefault(
      React.null,
      onClick => <button onClick={_ => onClick()}>
        {React.string("Click me")}
      </button>
    )}
  </div>
}
```

## Conversion Checklist
- [ ] Replace `@genType` with `@react.component`
- [ ] Convert props to labelled arguments with `~`
- [ ] Add `=?` for optional parameters
- [ ] Remove explicit type annotations unless required
- [ ] Convert inline styles to record syntax
- [ ] Use `React.string()` for all text content
- [ ] Fix event handlers with proper ReScript syntax
- [ ] Update module exports in `Client.res`
- [ ] Test compilation with `make build`
