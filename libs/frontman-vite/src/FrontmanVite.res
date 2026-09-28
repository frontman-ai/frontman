module Config = FrontmanVite__Config
module Middleware = FrontmanVite__Middleware
module Server = FrontmanVite__Server
module ToolRegistry = FrontmanVite__ToolRegistry
module Plugin = FrontmanVite__Plugin

module SSE = FrontmanAiFrontmanCore.FrontmanCore__SSE

@@live
let createMiddleware = Middleware.createMiddleware
@@live
let makeConfig = Config.makeFromObject
type config = Config.t
type configInput = Config.jsConfigInput

@@live
let frontmanPlugin = Plugin.frontmanPlugin
