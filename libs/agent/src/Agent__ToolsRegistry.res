// Tool registry - manages agent tools

// Tool is a first-class module implementing the Tool module type
type tool = module(Agent__Tool.T)

type t = array<tool>

// Create the tool registry with all available tools
let make = (): t => {
  [module(Agent__Tool__ListFiles), module(Agent__Tool__ReadFile), module(Agent__Tool__WriteFile)]
}
