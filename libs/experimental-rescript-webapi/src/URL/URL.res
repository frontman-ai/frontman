@new
external make: (~url: string, ~base: string=?) => UrlTypes.url = "URL"

@scope("URL")
external parse: (~url: string, ~base: string=?) => UrlTypes.url = "parse"

@scope("URL")
external canParse: (~url: string, ~base: string=?) => bool = "canParse"

@send
external toJSON: UrlTypes.url => string = "toJSON"

@scope("URL")
external createObjectURL: unknown => string = "createObjectURL"

@scope("URL")
external revokeObjectURL: string => unit = "revokeObjectURL"

module URLSearchParams = URLSearchParams
module Types = UrlTypes
