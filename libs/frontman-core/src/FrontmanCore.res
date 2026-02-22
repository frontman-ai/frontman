// Frontman Core - shared functionality for framework adapters

// Re-export core modules
module ToolRegistry = FrontmanCore__ToolRegistry
module SSE = FrontmanCore__SSE
module Server = FrontmanCore__Server
module SafePath = FrontmanCore__SafePath
module PathContext = FrontmanCore__PathContext

// Shared middleware layer
module CORS = FrontmanCore__CORS
module MiddlewareConfig = FrontmanCore__MiddlewareConfig
module RequestHandlers = FrontmanCore__RequestHandlers
module UIShell = FrontmanCore__UIShell
module Middleware = FrontmanCore__Middleware

// Re-export tools for direct access
module Tool = {
  module ReadFile = FrontmanCore__Tool__ReadFile
  module WriteFile = FrontmanCore__Tool__WriteFile
  module ListFiles = FrontmanCore__Tool__ListFiles
  module FileExists = FrontmanCore__Tool__FileExists
}
