@send
external iterateNext: DomTypes.xPathResult => DomTypes.node = "iterateNext"

@send
external snapshotItem: (DomTypes.xPathResult, int) => DomTypes.node = "snapshotItem"
