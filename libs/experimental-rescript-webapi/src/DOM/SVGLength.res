@send
external newValueSpecifiedUnits: (
  DomTypes.svgLength,
  ~unitType: int,
  ~valueInSpecifiedUnits: float,
) => unit = "newValueSpecifiedUnits"

@send
external convertToSpecifiedUnits: (DomTypes.svgLength, int) => unit = "convertToSpecifiedUnits"
