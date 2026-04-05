[
  # Ecto.Multi returns an opaque type that dialyzer doesn't understand well
  {"lib/frontman_server/organizations.ex", :call_without_opaque}
]
