@schema
type model = {value: string, name: string}

@schema
type group = {id: string, name: string, options: array<model>}

@schema
type t = {groups: array<group>}
