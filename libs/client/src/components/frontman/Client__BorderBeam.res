type animationType = [#sm | #md | #line | #"pulse-outside" | #"pulse-inner"]
type colorVariant = [#colorful | #mono | #ocean | #sunset]
type theme = [#dark | #light | #auto]

@module("border-beam") @react.component
external make: (
  ~children: React.element,
  ~size: animationType=?,
  ~colorVariant: colorVariant=?,
  ~theme: theme=?,
  ~duration: float=?,
  ~active: bool=?,
  ~borderRadius: float=?,
  ~strength: float=?,
  ~className: string=?,
  ~onFocus: ReactEvent.Focus.t => unit=?,
  ~onBlur: ReactEvent.Focus.t => unit=?,
) => React.element = "BorderBeam"
