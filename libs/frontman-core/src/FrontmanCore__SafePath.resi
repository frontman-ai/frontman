type t

let resolve: (~sourceRoot: string, ~inputPath: string) => result<t, string>

let toString: t => string

let dirname: t => string

let join: (~sourceRoot: string, t, array<string>) => result<t, string>
