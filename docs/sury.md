[⬅ Back to highlights](/README.md)

# ReScript API reference

## Table of contents

- [Table of contents](#table-of-contents)
- [Install](#install)
- [Basic usage](#basic-usage)
- [Real-world examples](#real-world-examples)
- [API reference](#api-reference)
  - [`string`](#string)
    - [ISO datetimes](#iso-datetimes)
  - [`bool`](#bool)
  - [`int`](#int)
  - [`float`](#float)
  - [`bigint`](#bigint)
  - [`symbol`](#symbol)
  - [`option`](#option)
  - [`Option.getOr`](#optiongetor)
  - [`Option.getOrWith`](#optiongetorwith)
  - [`null`](#null)
  - [`nullable`](#nullable)
  - [`nullableAsOption`](#nullableasoption)
  - [`unit`](#unit)
  - [`nullAsUnit`](#nullasunit)
  - [`literal`](#literal)
  - [`object`](#object)
    - [Transform object field names](#transform-object-field-names)
    - [Transform to a structurally typed object](#transform-to-a-structurally-typed-object)
    - [Transform to a tuple](#transform-to-a-tuple)
    - [Transform to a variant](#transform-to-a-variant)
    - [`s.flatten`](#sflatten)
    - [`s.nested`](#snested)
    - [`Object destructuring`](#object-destructuring)
  - [`strict`](#strict)
  - [`strip`](#strip)
  - [`deepStrict` & `deepStrip`](#deepstrict--deepstrip)
  - [`schema`](#schema)
  - [`to`](#to)
  - [`union`](#union)
    - [Enums](#enums)
  - [`array`](#array)
  - [`list`](#list)
  - [`unnest`](#unnest)
  - [`tuple`](#tuple)
  - [`tuple1` - `tuple3`](#tuple1---tuple3)
  - [`dict`](#dict)
  - [`unknown`](#unknown)
  - [`instance`](#instance)
  - [`never`](#never)
  - [`json`](#json)
  - [`jsonString`](#jsonString)
  - [`meta`](#meta)
  - [`recursive`](#recursive)
- [Custom schema](#custom-schema)
- [Refinements](#refinements)
- [Transforms](#transforms)
- [Functions on schema](#functions-on-schema)

  - [`Built-in operations`](#built-in-operations)
  - [`compile`](#compile)
  - [`reverse`](#reverse)
  - [`to`](#to)
  - [`isAsync`](#isasync)
  - [`name`](#name)
  - [`toExpression`](#toExpression)
  - [`noValidation`](#noValidation)

- [Error handling](#error-handling)
- [Global config](#global-config)
  - [`defaultAdditionalItems`](#defaultAdditionalItems)
  - [`disableNanNumberValidation`](#disablenannumbervalidation)

## Install

```sh
npm install sury
```

Then add `sury` to `bs-dependencies` in your `rescript.json`:

```diff
{
  ...
+ "bs-dependencies": ["sury"],
}
```

## Basic usage

```rescript
// 1. Define a type
type rating =
  | @as("G") GeneralAudiences
  | @as("PG") ParentalGuidanceSuggested
  | @as("PG13") ParentalStronglyCautioned
  | @as("R") Restricted
type film = {
  id: float,
  title: string,
  tags: array<string>,
  rating: rating,
  deprecatedAgeRestriction: option<int>,
}

// 2. Create a schema
let filmSchema = S.object(s => {
  id: s.field("Id", S.float),
  title: s.field("Title", S.string),
  tags: s.fieldOr("Tags", S.array(S.string), []),
  rating: s.field(
    "Rating",
    S.union([
      S.literal(GeneralAudiences),
      S.literal(ParentalGuidanceSuggested),
      S.literal(ParentalStronglyCautioned),
      S.literal(Restricted),
    ]),
  ),
  deprecatedAgeRestriction: s.field("Age", S.option(S.int)->S.deprecated("Use rating instead")),
})

// 3. Parse data using the schema
// The data is validated and transformed to a convenient format
{
  "Id": 1,
  "Title": "My first film",
  "Rating": "R",
  "Age": 17
}->S.parseOrThrow(filmSchema)
// {
//   id: 1.,
//   title: "My first film",
//   tags: [],
//   rating: Restricted,
//   deprecatedAgeRestriction: Some(17),
// }

// 4. Convert data back using the same schema
{
  id: 2.,
  tags: ["Loved"],
  title: "Sad & sed",
  rating: ParentalStronglyCautioned,
  deprecatedAgeRestriction: None,
}->S.reverseConvertOrThrow(filmSchema)
// {
//   "Id": 2,
//   "Title": "Sad & sed",
//   "Rating": "PG13",
//   "Tags": ["Loved"],
//   "Age": undefined,
// }

// 5. Use schema as a building block for other tools
// For example, create a JSON schema and use it for OpenAPI generation
let filmJSONSchema = filmSchema->S.toJSONSchema
```

The library uses `eval` to compile the most performant possible code for parsers and serializers. See yourself how good it is 👌

<details>

<summary>
Compiled parser code
</summary>

```javascript
(i) => {
  if (typeof i !== "object" || !i) {
    e[0](i);
  }
  let v0 = i["Id"],
    v1 = i["Title"];
  if (typeof v0 !== "number" || Number.isNaN(v0)) {
    e[1](v0);
  }
  if (typeof v1 !== "string") {
    e[2](v1);
  }
  let v2 = i["Tags"];
  if (Array.isArray(v2)) {
    for (let v3 = 0; v3 < v2.length; ++v3) {
      try {
        let v5 = v2[v3];
        if (typeof v5 !== "string") {
          e[3](v5);
        }
      } catch (v4) {
        if (v4 && v4.s === s) {
          v4.path = '["Tags"]' + "[\"'+v3+'\"]" + v4.path;
        }
        throw v4;
      }
    }
  } else if (v2 === void 0) {
    v2 = e[4];
  } else {
    e[5](v2);
  }
  let v6 = i["Rating"];
  if (
    !(
      typeof v6 === "string" &&
      (v6 === "G" || v6 === "PG" || v6 === "PG13" || v6 === "R")
    )
  ) {
    e[6](v6);
  }
  let v7 = i["Age"];
  if (
    !(
      (typeof v7 === "number" &&
        v7 < 2147483647 &&
        v7 > -2147483648 &&
        v7 % 1 === 0) ||
      v7 === void 0
    )
  ) {
    e[7](v7);
  }
  return {
    id: v0,
    title: v1,
    tags: v2,
    rating: v6,
    deprecatedAgeRestriction: v7,
  };
};
```

</details>
<details>

<summary>
Compiled serializer code
</summary>

```javascript
(i) => {
  let v0 = i["tags"],
    v3 = i["rating"],
    v4 = i["deprecatedAgeRestriction"];
  return { Id: i["id"], Title: i["title"], Tags: v0, Rating: v3, Age: v4 };
};
```

</details>

## Real-world examples

- [Reliable API layer](https://github.com/Nicolas1st/net-cli-rock-paper-scissors/blob/main/apps/client/src/Api.res)
- [Creating CLI utility](https://github.com/DZakh/rescript-stdlib-cli/blob/main/src/interactors/RunCli.res)
- [Safely accessing environment variables](https://github.com/Nicolas1st/net-cli-rock-paper-scissors/blob/main/apps/client/src/Env.res)

## API reference

### **`string`**

`S.t<string>`

```rescript
let schema = S.string

"Hello World!"->S.parseOrThrow(schema)
// "Hello World!"
```

The `S.string` schema represents a data that is a string. It can be further constrainted with the following utility methods.

**Sury** includes a handful of string-specific refinements and transforms:

```rescript
S.string->S.max(5) // String must be 5 or fewer characters long
S.string->S.min(5) // String must be 5 or more characters long
S.string->S.length(5) // String must be exactly 5 characters long
S.string->S.email // Invalid email address
S.string->S.url // Invalid url
S.string->S.uuid // Invalid UUID
S.string->S.cuid // Invalid CUID
S.string->S.pattern(%re(`/[0-9]/`)) // Invalid
S.string->S.datetime // Invalid datetime string! Expected UTC

S.string->S.trim // trim whitespaces
```

> ⚠️ Validating email addresses is nearly impossible with just code. Different clients and servers accept different things and many diverge from the various specs defining "valid" emails. The ONLY real way to validate an email address is to send a verification email to it and check that the user got it. With that in mind, Sury picks a relatively simple regex that does not cover all cases.

When using built-in refinements, you can provide a custom error message.

```rescript
S.string->S.min(1, ~message="String can't be empty")
S.string->S.length(5, ~message="SMS code should be 5 digits long")
```

#### ISO datetimes

The `S.string->S.datetime` function has following UTC validation: no timezone offsets with arbitrary sub-second decimal precision.

```rescript
let datetimeSchema = S.string->S.datetime
// The datetimeSchema has the type S.t<Date.t>
// String is transformed to the Date.t instance

"2020-01-01T00:00:00Z"->S.parseOrThrow(datetimeSchema) // pass
"2020-01-01T00:00:00.123Z"->S.parseOrThrow(datetimeSchema) // pass
"2020-01-01T00:00:00.123456Z"->S.parseOrThrow(datetimeSchema) // pass (arbitrary precision)
"2020-01-01T00:00:00+02:00"->S.parseOrThrow(datetimeSchema) // fail (no offsets allowed)
```

### **`bool`**

`S.t<bool>`

The `S.bool` schema represents a data that is a boolean.

### **`int`**

`S.t<int>`

The `S.int` schema represents a data that is an integer.

**Sury** includes some of int-specific refinements:

```rescript
S.int->S.max(5) // Number must be lower than or equal to 5
S.int->S.min(5) // Number must be greater than or equal to 5
S.int->S.port // Invalid port
```

### **`float`**

`S.t<float>`

The `S.float` schema represents a data that is a number.

**Sury** includes some of float-specific refinements:

```rescript
S.float->S.floatMax(5.) // Number must be lower than or equal to 5
S.float->S.floatMin(5.) // Number must be greater than or equal to 5
```

### **`bigint`**

`S.t<bigint>`

The `S.bigint` schema represents a data that is a BigInt.

### **`symbol`**

`S.t<symbol>`

The `S.symbol` schema represents a data that is a symbol.

### **`option`**

`S.t<'value> => S.t<option<'value>>`

```rescript
let schema = S.option(S.string)

"Hello World!"->S.parseOrThrow(schema)
// Some("Hello World!")
%raw(`undefined`)->S.parseOrThrow(schema)
// None
```

The `S.option` schema represents a data of a specific type that might be undefined.

### **`Option.getOr`**

`(S.t<option<'value>>, 'value) => S.t<'value>`

```rescript
let schema = S.option(S.string)->S.Option.getOr("Hello World!")

%raw(`undefined`)->S.parseOrThrow(schema)
// "Hello World!"
"Goodbye World!"->S.parseOrThrow(schema)
// "Goodbye World!"
```

The `Option.getOr` augments a schema to add transformation logic for default values, which are applied when the input is undefined.

> 🧠 If you want to set a default value for an object field, there's a more convenient `fieldOr` method on `Object.s` type.

### **`Option.getOrWith`**

`(S.t<option<'value>>, () => 'value) => S.t<'value>`

```rescript
let schema = S.option(S.array(S.string))->S.Option.getOrWith(() => ["Hello World!"])

%raw(`undefined`)->S.parseOrThrow(schema)
// ["Hello World!"]
["Goodbye World!"]->S.parseOrThrow(schema)
// ["Goodbye World!"]
```

Also you can use `Option.getOrWith` for lazy evaluation of the default value.

### **`null`**

`S.t<'value> => S.t<option<'value>>`

```rescript
let schema = S.null(S.string)

"Hello World!"->S.parseOrThrow(schema)
// Some("Hello World!")
%raw(`null`)->S.parseOrThrow(schema)
// None
```

The `S.null` schema represents a data of a specific type that might be null.

> 🧠 Since `S.null` transforms value into `option` type, you can use `Option.getOr`/`Option.getOrWith` for it as well.

### **`nullable`**

`S.t<'value> => S.t<Nullable.t<'value>>`

```rescript
let schema = S.nullable(S.string)

"Hello World!"->S.parseOrThrow(schema)
// Some("Hello World!")
%raw(`null`)->S.parseOrThrow(schema)
// Null
%raw(`undefined`)->S.parseOrThrow(schema)
// Undefined
```

The `S.nullable` schema represents a data of `Nullable.t` that might be null or undefined.

### **`nullableAsOption`**

`S.t<'value> => S.t<option<'value>>`

The same as `S.nullable`, but returns `option` type instead of `Nullable.t`. When serializing, it will return `undefined` for `None` values.

### **`unit`**

`S.t<unit>`

The `S.unit` schema is a shorthand for `S.literal()`.

### **`nullAsUnit`**

`S.t<unit>`

The `S.nullAsUnit` schema is a shorthand for `S.literal(Null.null)->S.to(S.unit)`.

### **`literal`**

`'value => S.t<'value>`

```rescript
let tunaSchema = S.literal("Tuna")
let twelveSchema = S.literal(12)
let importantTimestampSchema = S.literal(1652628345865.)
let truSchema = S.literal(true)
let nullSchema = S.literal(Null.null) // Or use S.nullAsUnit
let undefinedSchema = S.literal() // Or use S.unit

// Uses Number.isNaN to match NaN literals
let nanSchema = S.literal(Float.Constants.nan)->S.shape(_ => ()) // For NaN literals I recomment adding S.shape to transform it to unit. It's better than having it as a float type

// Supports symbols and BigInt
let symbolSchema = S.literal(Symbol.asyncIterator)
let twobigSchema = S.literal(BigInt.fromInt(2))

// Supports variants and polymorphic variants
let appleSchema = S.literal(#apple)
let noneSchema = S.literal(None)

// Does a deep check for plain objects and arrays
let cliArgsSchema = S.literal(("help", "lint"))

// Supports functions and literally any Js values matching them with the === operator
let fn = () => "foo"
let fnSchema = S.literal(fn)
let weakMap = WeakMap.make()
let weakMapSchema = S.literal(weakMap)
```

The `S.literal` schema enforces that a data matches an exact value during parsing and serializing.

### **`object`**

`(S.Object.s => 'value) => S.t<'value>`

```rescript
type point = {
  x: int,
  y: int,
}

// The pointSchema will have the S.t<point> type
let pointSchema = S.object(s => {
  x: s.field("x", S.int),
  y: s.field("y", S.int),
})

// It can be used both for parsing and serializing
{"x": 1, "y": -4}->S.parseOrThrow(pointSchema)
{x: 1, y: -4}->S.reverseConvertOrThrow(pointSchema)
```

The `object` schema represents an object value, that can be transformed into any ReScript value. Here are some examples:

#### Transform object field names

```rescript
type user = {
  id: int,
  name: string,
}
// It will have the S.t<user> type
let schema = S.object(s => {
  id: s.field("USER_ID", S.int),
  name: s.field("USER_NAME", S.string),
})

{
  "USER_ID": 1,
  "USER_NAME": "John",
}->S.parseOrThrow(schema)
// {id: 1, name: "John"}
{id: 1, name: "John"}->S.reverseConvertOrThrow(schema)
// {"USER_ID": 1, "USER_NAME": "John"}
```

#### Transform to a structurally typed object

```rescript
// It will have the S.t<{"key1":string,"key2":string}> type
let schema = S.object(s => {
  "key1": s.field("key1", S.string),
  "key2": s.field("key2", S.string),
})
```

#### Transform to a tuple

```rescript
// It will have the S.t<(int, string)> type
let schema = S.object(s => (s.field("USER_ID", S.int), s.field("USER_NAME", S.string)))

{"USER_ID":1,"USER_NAME":"John"}->S.parseOrThrow(schema)
// (1, "John")
```

The same schema also works for serializing:

```rescript
(1, "John")->S.reverseConvertOrThrow(schema)
// {"USER_ID":1,"USER_NAME":"John"}
```

#### Transform to a variant

```rescript
type shape = Circle({radius: float}) | Square({x: float}) | Triangle({x: float, y: float})

// It will have the S.t<shape> type
let schema = S.object(s => {
  s.tag("kind", "circle")
  Circle({
    radius: s.field("radius", S.float),
  })
})

{
  "kind": "circle",
  "radius": 1,
}->S.parseOrThrow(schema)
// Circle({radius: 1})
```

For values whose runtime representation matches your schema, you can use the less verbose `S.schema`. Under the hood, it'll create the same `S.object` schema from the example above.

```rescript
@tag("kind")
type shape =
  | @as("circle") Circle({radius: float})
  | @as("square") Square({x: float})
  | @as("triangle") Triangle({x: float, y: float})

let schema = S.schema(s => Circle({
  radius: s.matches(S.float),
}))
```

You can use the schema for parsing as well as serializing:

```rescript
Circle({radius: 1})->S.reverseConvertOrThrow(schema)
// {
//   "kind": "circle",
//   "radius": 1,
// }
```

#### `s.flatten`

It's possible to spread/flatten an object schema in another object schema, allowing you to reuse schemas in a more powerful way.

```rescript
type entityData = {
  name: option<string>,
  age: int,
}
type entity = {
  id: string,
  ...entityData,
}

let entityDataSchema = S.object(s => {
  name: s.fieldOr("name", S.string, "Unknown"),
  age: s.field("age", S.int),
})
let entitySchema = S.object(s => {
  let {name, age} = s.flatten(entityDataSchema)
  {
    id: s.field("id", S.string),
    name,
    age,
  }
})
```

#### `s.nested`

A nice way to parse nested fields:

```rescript
let schema = S.object(s => {
  {
    id: s.field("id", S.string),
    name: s.nested("data").fieldOr("name", S.string, "Unknown")
    age: s.nested("data").field("age", S.int),
  }
})
```

The `s.nested` returns a complete `S.Object.s` context of the nested object, which you can use to define nested schema without any limitations.

#### Object destructuring

It's possible to destructure object field schemas inside of definition. You could also notice it in the `s.flatten` example 😁

```rescript
let entitySchema = S.object(s => {
  let {name, age} = s.field("data", entityDataSchema)
  {
    id: s.field("id", S.string),
    name,
    age,
  }
})
```

> 🧠 While the example with `s.flatten` expect an object with the type `{id: string, name: option<string>, age: int}`, the example above as well as for `s.nested` will expect an object with the type `{id: string, data: {name: option<string>, age: int}}`.

### **`strict`**

`S.t<'value> => S.t<'value>`

```rescript
// Represents an object without fields
let schema = S.object(_ => ())->S.strict

{
  "someField": "value",
}->S.parseOrThrow(schema)
// throws S.error with the message: `Failed parsing: Unrecognized key  "unknownKey"`
```

By default **Sury** silently strips unrecognized keys when parsing objects. You can change the behaviour to disallow unrecognized keys with the `S.strict` function.

If you want to change it for all schemas in your app, you can use `S.global` function:

```rescript
S.global({
  defaultAdditionalItems: Strict,
})
```

### **`strip`**

`S.t<'value> => S.t<'value>`

```rescript
// Represents an object with any fields
let schema = S.object(_ => ())->S.strip

{
  "someField": "value",
}->S.parseOrThrow(schema)
// ()
```

You can use the `S.strip` function to reset a object schema to the default behavior (stripping unrecognized keys).

### **`deepStrict` & `deepStrip`**

Both `S.strict` and `S.strip` are applied for the first level of the object schema. If you want to apply it for all nested schemas, you can use `S.deepStrict` and `S.deepStrip` functions.

```rescript
let schema = S.schema(s =>
  {
    "bar": {
      "baz": s.matches(S.string),
    }
  }
)

schema->S.strict // {"baz": string} will still allow unknown keys
schema->S.deepStrict // {"baz": string} will not allow unknown keys
```

### **`schema`**

`(S.Schema.s => 'value) => S.t<'value>`

It's a helper built on `S.literal`, `S.object`, and `S.tuple` to create schemas for runtime representation of ReScript types conveniently.

```rescript
@unboxed
type answer =
  | Text(string)
  | MultiSelect(array<string>)
  | Other({value: string, @as("description") maybeDescription: option<string>})

let textSchema = S.schema(s => Text(s.matches(S.string)))
// It's going to be the same as:
// S.string->S.shape(string => Text(string))

let multySelectSchema = S.schema(s => MultiSelect(s.matches(S.array(S.string))))
// The same as:
// S.array(S.string)->S.shape(array => MultiSelect(array))

let otherSchema = S.schema(s => Other({
  value: s.matches(S.string),
  maybeDescription: s.matches(S.option(S.string)),
}))
// Creates the schema under the hood:
// S.object(s => Other({
//   value: s.field("value", S.string),
//   maybeDescription: s.field("description", S.option(S.string)),
// }))
//       Notice how the field name /|\ is taken from the type's @as attribute

let tupleExampleSchema = S.schema(s => (#id, s.matches(S.string)))
// The same as:
// S.tuple(s => (s.item(0, S.literal(#id)), s.item(1, S.string)))
```

> 🧠 Note that `S.schema` relies on the runtime representation of your type, while `S.object`/`S.tuple` are more flexible and require you to describe the schema explicitly.

### **`shape`**

`(S.t<'value>, 'value => 'shape) => S.t<'shape>`

The `S.shape` schema is a helper function that allows you to transform the value to a desired shape. It'll statically derive required data transformations to perform the change in the most optimal way.

> ⚠️ Even though it looks like you operate with a real value, it's actually a dummy proxy object. So conditions or any other runtime logic won't work. Please use `S.transform` for such cases.

```rescript
type shape = Circle({radius: float}) | Square({x: float}) | Triangle({x: float, y: float})

// It will have the S.t<shape> type
let schema = S.float->S.shape(radius => Circle({radius: radius}))

1->S.parseOrThrow(schema)
// Circle({radius: 1.})
```

The same schema also works for serializing:

```rescript
Circle({radius: 1})->S.reverseConvertOrThrow(schema)
// 1
```

### **`union`**

`array<S.t<'value>> => S.t<'value>`

An union represents a logical OR relationship. You can apply this concept to your schemas with `S.union`. This is the best API to use for variants and polymorphic variants.

On validation, the `S.union` schema returns the result of the first item that was successfully validated.

> 🧠 Schemas are not guaranteed to be validated in the order they are passed to `S.union`. They are grouped by the input data type to optimise performance and improve error message. Schemas with unknown data typed validated the last.

```rescript
// TypeScript type for reference:
// type Shape =
// | { kind: "circle"; radius: number }
// | { kind: "square"; x: number }
// | { kind: "triangle"; x: number; y: number };
type shape = Circle({radius: float}) | Square({x: float}) | Triangle({x: float, y: float})

let shapeSchema = S.union([
  S.object(s => {
    s.tag("kind", "circle")
    Circle({
      radius: s.field("radius", S.float),
    })
  }),
  S.object(s => {
    s.tag("kind", "square")
    Square({
      x: s.field("x", S.float),
    })
  }),
  S.object(s => {
    s.tag("kind", "triangle")
    Triangle({
      x: s.field("x", S.float),
      y: s.field("y", S.float),
    })
  }),
])
```

```rescript
{
  "kind": "circle",
  "radius": 1,
}->S.parseOrThrow(shapeSchema)
// Circle({radius: 1.})
```

```rescript
Square({x: 2.})->S.reverseConvertOrThrow(shapeSchema)
// {
//   "kind": "square",
//   "x": 2,
// }
```

#### Enums

Also, you can describe a schema for a enum-like variant using `S.union` together with `S.literal`.

```rescript
type outcome = | @as("win") Win | @as("draw") Draw | @as("loss") Loss

let schema = S.union([
  S.literal(Win),
  S.literal(Draw),
  S.literal(Loss),
])

"draw"->S.parseOrThrow(schema)
// Draw
```

Also, you can use `S.enum` as a shorthand for the use case above.

```rescript
let schema = S.enum([Win, Draw, Loss])
```

### **`array`**

`S.t<'value> => S.t<array<'value>>`

```rescript
let schema = S.array(S.string)

["Hello", "World"]->S.parseOrThrow(schema)
// ["Hello", "World"]
```

The `S.array` schema represents an array of data of a specific type.

**Sury** includes some of array-specific refinements:

```rescript
S.array(itemSchema)->S.max(5) // Array must be 5 or fewer items long
S.array(itemSchema)->S.min(5) // Array must be 5 or more items long
S.array(itemSchema)->S.length(5) // Array must be exactly 5 items long
```

### **`list`**

`S.t<'value> => S.t<list<'value>>`

```rescript
let schema = S.list(S.string)

["Hello", "World"]->S.parseOrThrow(schema)
// list{"Hello", "World"}
```

The `S.list` schema represents an array of data of a specific type which is transformed to ReScript's list data-structure.

### **`unnest`**

`S.t<'value> => S.t<array<'value>>`

```rescript
let schema = S.unnest(S.schema(s => {
  id: s.matches(S.string),
  name: s.matches(S.null(S.string)),
  deleted: s.matches(S.bool),
}))

[{id: "0", name: Some("Hello"), deleted: false}, {id: "1", name: None, deleted: true}]->S.reverseConvertOrThrow(schema)
// [["0", "1"], ["Hello", null], [false, true]]
```

The helper function is inspired by the article [Boosting Postgres INSERT Performance by 2x With UNNEST](https://www.timescale.com/blog/boosting-postgres-insert-performance). It allows you to flatten a nested array of objects into arrays of values by field.

The main concern of the approach described in the article is usability. And ReScript Schema completely solves the problem, providing a simple and intuitive API that is even more performant than `S.array`.

<details>

<summary>
Checkout the compiled code yourself:
</summary>

```javascript
(i) => {
  let v1 = [new Array(i.length), new Array(i.length), new Array(i.length)];
  for (let v0 = 0; v0 < i.length; ++v0) {
    let v3 = i[v0];
    try {
      let v4 = v3["name"];
      if (v4 === void 0) {
        v4 = null;
      }
      v1[0][v0] = v3["id"];
      v1[1][v0] = v4;
      v1[2][v0] = v3["deleted"];
    } catch (v2) {
      if (v2 && v2.s === s) {
        v2.path = "" + "[\"'+v0+'\"]" + v2.path;
      }
      throw v2;
    }
  }
  return v1;
};
```

</details>

### **`tuple`**

`(S.Tuple.s => 'value) => S.t<'value>`

```rescript
type point = {
  x: int,
  y: int,
}

// The pointSchema will have the S.t<point> type
let pointSchema = S.tuple(s => {
  s.tag(0, "point")
  {
    x: s.item(1, S.int),
    y: s.item(2, S.int),
  }
})

// It can be used both for parsing and serializing
["point", 1, -4]->S.parseOrThrow(pointSchema)
{ x: 1, y: -4 }->S.reverseConvertOrThrow(pointSchema)
```

The `S.tuple` schema represents that a data is an array of a specific length with values each of a specific type.

For short tuples without the need for transformation, there are wrappers over `S.tuple`:

### **`tuple1` - `tuple3`**

`(S.t<'v0>, S.t<'v1>, S.t<'v2>) => S.t<('v0, 'v1, 'v2)>`

```rescript
let schema = S.tuple3(S.string, S.int, S.bool)

%raw(`["a", 1, true]`)->S.parseOrThrow(schema)
// ("a", 1, true)
```

### **`dict`**

`S.t<'value> => S.t<dict<'value>>`

```rescript
let schema = S.dict(S.string)

{
  "foo": "bar",
  "baz": "qux",
}->S.parseOrThrow(schema)
// dict{foo: "bar", baz: "qux"}
```

The `dict` schema represents a dictionary of data of a specific type.

### **`instance`**

`S.t<instance>`

```rescript
let schema: S.t<Set.t<string>> = S.instance(%raw(`Set`))->Obj.magic;
```

The `S.instance` schema represents an instance of a class. Requires some type casting to make it work, but better than `S.unknown` as a building block for more complex schemas.

### **`unknown`**

`S.t<unknown>`

```rescript
let schema = S.unknown

"Hello World!"->S.parseOrThrow(schema)
// "Hello World!"
```

The `S.unknown` schema represents any data.

### **`never`**

`S.t<S.never>`

```rescript
let schema = S.never

%raw(`undefined`)->S.parseOrThrow(schema)
// throws S.error with the message: `Failed parsing: Expected never, received undefined`
```

The `never` schema will fail parsing for every value.

### **`json`**

`S.t<JSON.t>`

```rescript
S.enableJson() // ❕ Call at the project root.

let schema = S.json

`"abc"`->S.parseOrThrow(schema)
// "abc" of type JSON.t
```

The `S.json` schema represents a data that is compatible with JSON.

### **`jsonString`**

`S.t<string>`

```rescript
S.enableJsonString() // ❕ Call at the project root.

let schema = S.jsonString->S.to(S.int)

"123"->S.parseOrThrow(schema)
// 123
```

The `S.jsonString` schema represents JSON string.

There's also `S.jsonStringWithSpace` to configure space in the JSON string during serialization.

### **`meta`**

`(S.t<'value>, S.meta) => S.t<'value>`

Use `S.meta` to add a metadata to the resulting schema.

```rescript
let documentedStringSchema = S.string
  ->S.meta({description: "A useful bit of text, if you know what to do with it."})

(documentedStringSchema->S.untag).description // A useful bit of text…
```

This can be useful for documenting fields, generating JSON, etc.

```rescript
schema->S.toJSONSchema
// {
//   "type": "string",
//   "description": "A useful bit of text, if you know what to do with it."
// }
```

### **`recursive`**

`(string, t<'value> => t<'value>) => t<'value>`

You can define a recursive schema in **Sury**.

```rescript
type rec node = {
  id: string,
  children: array<node>,
}

let nodeSchema = S.recursive("Node", nodeSchema => {
  S.object(s => {
    id: s.field("Id", S.string),
    children: s.field("Children", S.array(nodeSchema)),
  })
})
```

```rescript
{
  "Id": "1",
  "Children": [
    {"Id": "2", "Children": []},
    {"Id": "3", "Children": [{"Id": "4", "Children": []}]},
  ],
}->S.parseOrThrow(nodeSchema)
// {
//   id: "1",
//   children: [{id: "2", children: []}, {id: "3", children: [{id: "4", children: []}]}],
// }
```

The same schema works for serializing:

```rescript
{
  id: "1",
  children: [{id: "2", children: []}, {id: "3", children: [{id: "4", children: []}]}],
}->S.reverseConvertOrThrow(nodeSchema)
// {
//   "Id": "1",
//   "Children": [
//     {"Id": "2", "Children": []},
//     {"Id": "3", "Children": [{"Id": "4", "Children": []}]},
//   ],
// }
```

You can also use asynchronous parser:

```rescript
let nodeSchema = S.recursive("Node", nodeSchema => {
  S.object(s => {
    params: s.field("Id", S.string)->S.transform(_ => {asyncParser: id => loadParams(~id)}),
    children: s.field("Children", S.array(nodeSchema)),
  })
})
```

One great aspect of the example above is that it uses parallelism to make four requests to check for the existence of nodes.

> 🧠 Despite supporting recursive schema, passing cyclical data will cause an infinite loop.

## Custom schema

**Sury** might not have many built-in schemas for your use case. In this case you can create a custom schema for any TypeScript type.

1. Choose a base schema which is the closest to your type. Most likely it'll be `S.instance`.
2. Use `S.transform` to add a custom parser and serializer.
3. Optionally, use `S.meta` to add customize the name of the schema and additional metadata.

```rescript
let mySet = itemSchema => {
  S.instance(%raw(`Set`))
  ->S.transform(_ => {
    parser: input => {
      let output = Set.make()
      input
      ->Obj.magic
      ->Set.forEach(
        item => {
          output->Set.add(S.parseOrThrow(item, itemSchema))
        },
      )
      output
    },
  })
  ->S.meta({name: `Set.t<${S.toExpression(itemSchema)}>`})
}

let intSetSchema = mySet(S.int)

S.parseOrThrow(%raw(`new Set([1, 2, 3])`), intSetSchema) // passes
S.parseOrThrow(%raw(`new Set([1, 2, "3"])`), intSetSchema) // throws S.Error: Failed parsing: Expected int32, received "3"
S.parseOrThrow(%raw(`[1, 2, 3]`), intSetSchema) // throws S.Error: Failed parsing: Expected Set.t<int32>, received [1, 2, 3]
```

## Refinements

**Sury** lets you provide custom validation logic via refinements. It's useful to add checks that's not possible to cover with type system. For instance: checking that a number is an integer or that a string is a valid email address.

### **`refine`**

`(S.t<'value>, S.s<'value> => 'value => unit) => S.t<'value>`

```rescript
let shortStringSchema = S.string->S.refine(s => value =>
  if value->String.length > 255 {
    s.fail("String can't be more than 255 characters")
  }
)
```

The refine function is applied for both parser and serializer.

## Transforms

**Sury** allows to augment schema with transformation logic, letting you transform value during parsing and serializing. This is most commonly used for mapping value to more convenient data-structures.

### **`transform`**

`(S.t<'input>, S.s<'output> => S.transformDefinition<'input, 'output>) => S.t<'output>`

```rescript
let intToString = schema =>
  schema->S.transform(s => {
    parser: int => int->Int.toString,
    serializer: string =>
      switch string->Int.fromString {
      | Some(int) => int
      | None => s.fail("Can't convert string to int")
      },
  })
```

Also, you can have an asynchronous transform:

```rescript
type user = {
  id: string,
  name: string,
}

let userSchema =
  S.string
  ->S.uuid
  ->S.transform(s => {
    asyncParser: userId => loadUser(~userId),
    serializer: user => user.id,
  })

await "1"->S.parseAsyncOrThrow(userSchema)
// {
//   id: "1",
//   name: "John",
// }

{
  id: "1",
  name: "John",
}->S.reverseConvertOrThrow(userSchema)
// "1"
```

## Functions on schema

### Built-in operations

The library provides a bunch of built-in operations that can be used to parse, convert, and assert values.

Parsing means that the input value is validated against the schema and transformed to the expected output type. You can use the following operations to parse values:

| Operation                | Interface                                | Description                                                   |
| ------------------------ | ---------------------------------------- | ------------------------------------------------------------- |
| S.parseOrThrow           | `('any, S.t<'value>) => 'value`          | Parses any value with the schema                              |
| S.parseJsonOrThrow       | `(Js.Json.t, S.t<'value>) => 'value`     | Parses JSON value with the schema                             |
| S.parseJsonStringOrThrow | `(string, S.t<'value>) => 'value`        | Parses JSON string with the schema                            |
| S.parseAsyncOrThrow      | `('any, S.t<'value>) => promise<'value>` | Parses any value with the schema having async transformations |

For advanced users you can only transform to the output type without type validations. But be careful, since the input type is not checked:

| Operation                    | Interface                                | Description                                                        |
| ---------------------------- | ---------------------------------------- | ------------------------------------------------------------------ |
| S.convertOrThrow             | `('any, S.t<'value>) => 'value`          | Converts any value to the output type                              |
| S.convertToJsonOrThrow       | `('any, S.t<'value>) => Js.Json.t`       | Converts any value to JSON                                         |
| S.convertToJsonStringOrThrow | `('any, S.t<'value>) => string`          | Converts any value to JSON string                                  |
| S.convertAsyncOrThrow        | `('any, S.t<'value>) => promise<'value>` | Converts any value to the output type having async transformations |

Note, that in this case only type validations are skipped. If your schema has refinements or transforms, they will be applied.

Also, you can use `S.noValidation` helper to turn off type validations for the schema even when it's used with a parse operation.

More often than converting input to output, you'll need to perform the reversed operation. It's usually called "serializing" or "decoding". The ReScript Schema has a unique mental model and provides an ability to reverse any schema with `S.reverse` which you can later use with all possible kinds of operations. But for convinence, there's a few helper functions that can be used to convert output values to the initial format:

| Operation                           | Interface                                | Description                                                           |
| ----------------------------------- | ---------------------------------------- | --------------------------------------------------------------------- |
| S.reverseConvertOrThrow             | `('value, S.t<'value>) => 'any`          | Converts schema value to the output type                              |
| S.reverseConvertToJsonOrThrow       | `('value, S.t<'value>) => Js.Json.t`     | Converts schema value to JSON                                         |
| S.reverseConvertToJsonStringOrThrow | `('value, S.t<'value>) => string`        | Converts schema value to JSON string                                  |
| S.reverseConvertAsyncOrThrow        | `('value, S.t<'value>) => promise<'any>` | Converts schema value to the output type having async transformations |

This is literally the same as convert operations applied to the reversed schema.

For some cases you might want to simply assert the input value is valid. For this there's `S.assertOrThrow` operation:

| Operation       | Interface                   | Description                                                                                                                                          |
| --------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| S.assertOrThrow | `('any, S.t<'value>) => ()` | Asserts that the input value is valid. Since the operation doesn't return a value, it's 2-3 times faster than `parseOrThrow` depending on the schema |

All operations either return the output value or throw an exception which you can catch with `try/catch` block:

```rescript
try true->S.parseOrThrow(schema) catch {
| S.Error(error) => Console.log(error.message)
}
```

### **`compile`**

`(S.t<'value>, ~input: input<'value, 'input>, ~output: output<'value, 'transformedOutput>, ~mode: mode<'transformedOutput, 'output>, ~typeValidation: bool=?) => 'input => 'output`

If you want to have the most possible performance, or the built-in operations doesn't cover your specific use case, you can use `compile` to create fine-tuned operation functions.

```rescript
let operation = S.compile(
  S.string,
  ~input=Any,
  ~output=Assert,
  ~mode=Async,
)
await operation("Hello world!")
// ()
```

For example, in the example above we've created an async assert operation, which is not available by default.

You can configure compiled function `input` with the following options:

- `Value` - accepts `'value` of `S.t<'value>` and reverses the operation
- `Unknown` - accepts `unknown`
- `Any` - accepts `'any`
- `Json` - accepts `Js.Json.t`
- `JsonString` - accepts `string` and applies `JSON.parse` before parsing

You can configure compiled function `output` with the following options:

- `Value` - returns `'value` of `S.t<'value>`
- `Unknown` - returns `unknown`
- `Assert` - returns `unit`
- `Json` - validates that the schema is JSON compatible and returns `Js.Json.t`
- `JsonString` - validates that the schema is JSON compatible and converts output to JSON string

You can configure compiled function `mode` with the following options:

- `Sync` - for sync operations
- `Async` - for async operations - will wrap result in a promise

And you can configure compiled function `typeValidation` with the following options:

- `true (default)` - performs type validation
- `false` - doesn't perform type validation and only converts data to the output format. Note that refines are still applied.

### **`reverse`**

`(S.t<'value>) => S.t<'value>`

```rescript
S.null(S.string)->S.reverse
// S.option(S.string)
```

```rescript
let schema = S.object(s => s.field("foo", S.string))

{"foo": "bar"}->S.parseOrThrow(schema)
// "bar"

let reversed = schema->S.reverse

"bar"->S.parseOrThrow(reversed)
// {"foo": "bar"}

123->S.parseOrThrow(reversed)
// throws S.error with the message: `Failed parsing: Expected string, received 123`
```

Reverses the schema. This gets especially magical for schemas with transformations 🪄

### **`to`**

`(S.t<'from>, S.t<'to>) => S.t<'to>`

This very powerful API allows you to coerce another data type in a declarative way. Let's say you receive a number that is passed to your system as a string. For this `S.to` is the best fit:

```rescript
let schema = S.string->S.to(S.float)

"123"->S.parseOrThrow(schema) //? 123.
"abc"->S.parseOrThrow(schema) //? throws: Failed parsing: Expected number, received "abc"

// Reverse works correctly as well 🔥
123.->S.reverseConvertOrThrow(schema) //? "123"
```

### **`isAsync`**

`(S.t<'value>) => bool`

```rescript
S.string->S.isAsync
// false
S.string->S.transform(_ => {asyncParser: i => Promise.resolve(i)})->S.isAsync
// true
```

Determines if the schema is async. It can be useful to decide whether you should use async operation.

### **`name`**

```rescript
let schema = S.literal({"abc": 123})->S.meta({name: "Abc"})

(schema->S.untag).name // "Abc"
```

Used internally for readable error messages.

### **`toExpression`**

`(S.t<'value>) => string`

```rescript
S.literal({"abc": 123})->S.toExpression
// "{ "abc": 123 }"

S.string->S.name("Address")->S.toExpression
// "Address"
```

Used internally for readable error messages.

> 🧠 The format subject to change

### **`noValidation`**

`(S.t<'value>, bool) => S.t<'value>`

```rescript
let schema = S.object(s => s.field("abc", S.int))->S.noValidation(true)

{
  "abc": 123,
}->S.parseOrThrow(schema) // This doesn't have `if (typeof i !== "object" || !i) {` check. But field types are still validated.
// 123
```

Removes validation for the provided schema. Nested schemas are not affected.

This can be useful to optimise `S.object` parsing when you construct the input data yourself.

## Error handling

**Sury** throws `S.error` error containing detailed information about the validation problems.

```rescript
let schema = S.literal(false)

true->S.parseOrThrow(schema)
// throws S.error with the message: `Failed parsing: Expected false, received true`
```

If you want to handle the error, the best way to use `try/catch` block:

```rescript
try true->S.parseOrThrow(schema) catch {
| S.Error(error) => Console.log(error.message)
}
```

## Global config

**Sury** has a global config that can be changed to customize the behavior of the library.

### `defaultAdditionalItems`

`defaultAdditionalItems` is an option that controls how unknown keys are handled when parsing objects. The default value is `Strip`, but you can globally change it to `Strict` to enforce strict object parsing.

```rescript
S.global({
  defaultAdditionalItems: Strict,
})
```

### `disableNanNumberValidation`

`disableNanNumberValidation` is an option that controls whether the library should check for NaN values when parsing numbers. The default value is `false`, but you can globally change it to `true` to allow NaN values. If you parse many numbers which are guaranteed to be non-NaN, you can set it to `true` to improve performance ~10%, depending on the case.

```rescript
S.global({
  disableNanNumberValidation: true,
})
```
