// Node.js os module bindings
@module("node:os")
external homedir: unit => string = "homedir"

@module("node:os")
external platform: unit => string = "platform"

@module("node:os")
external tmpdir: unit => string = "tmpdir"
