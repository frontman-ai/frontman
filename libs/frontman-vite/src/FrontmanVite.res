module Config = FrontmanVite__Config
module Middleware = FrontmanVite__Middleware
module ToolRegistry = FrontmanVite__ToolRegistry
module Plugin = FrontmanVite__Plugin

@@live
let createMiddleware = Middleware.createMiddleware
@@live
let makeConfig = Config.makeFromObject
type config = Config.t
type configInput = Config.jsConfigInput

@@live
let frontmanPlugin = Plugin.frontmanPlugin
