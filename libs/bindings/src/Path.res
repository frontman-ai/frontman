// Path module bindings using node: prefix
@module("node:path") @variadic
external join: array<string> => string = "join"

@module("node:path")
external dirname: string => string = "dirname"

@module("node:path")
external basename: string => string = "basename"

@module("node:path")
external extname: string => string = "extname"

@module("node:path")
external resolve: string => string = "resolve"

@module("node:path")
external isAbsolute: string => bool = "isAbsolute"

@module("node:path")
external normalize: string => string = "normalize"

@module("node:path") @variadic
external resolveMany: array<string> => string = "resolve"

@module("node:path")
external sep: string = "sep"
