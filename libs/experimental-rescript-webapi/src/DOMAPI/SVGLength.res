open DOMAPI

@send
external newValueSpecifiedUnits: (
  svgLength,
  ~unitType: int,
  ~valueInSpecifiedUnits: float,
) => unit = "newValueSpecifiedUnits"

@send
external convertToSpecifiedUnits: (svgLength, int) => unit = "convertToSpecifiedUnits"
