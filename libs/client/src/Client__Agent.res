module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

type t = ACP.agentCatalogEntry

let findOrThrow = (catalog: option<array<ACP.agentCatalogEntry>>, agentId: string): t => {
  let catalog = catalog->Option.getOrThrow(~message="Agent catalog is required")
  catalog
  ->Array.find(agent => agent.id == agentId)
  ->Option.getOrThrow(~message=`Unknown agent: ${agentId}`)
}
