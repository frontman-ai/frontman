@react.component
let make = (~agent: Client__Agent.t, ~className="mb-1.5", ~borderColor=?) => {
  let borderColor = borderColor->Option.getOr(`color-mix(in srgb, ${agent.color} 28%, transparent)`)

  <span
    className={`inline-flex h-5 w-fit items-center gap-1.5 rounded-full border px-2 text-[10px] font-medium tracking-wide ${className}`}
    style={{color: agent.color, backgroundColor: "#08050D", borderColor}}
    title=agent.description
    ariaLabel={`${agent.displayName}: ${agent.description}`}
  >
    <span className="size-1.5 rounded-full" style={{backgroundColor: agent.color}} />
    {React.string(agent.displayName)}
  </span>
}
