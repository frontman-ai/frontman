module Config = FrontmanAstro__Config
module Middleware = FrontmanAstro__Middleware
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry
module Integration = FrontmanAstro__Integration
module ViteAdapter = FrontmanAstro__ViteAdapter

module SSE = FrontmanAiFrontmanCore.FrontmanCore__SSE

@@live
let frontmanIntegration = Integration.make

type config = Config.t
type configInput = Config.jsConfigInput
let makeConfig = Config.makeFromObject
