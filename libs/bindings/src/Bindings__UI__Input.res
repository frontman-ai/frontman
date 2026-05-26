// UI Input component bindings
// Usage:
// <UI__Input type_=#email placeholder="Enter email" value={email} onChange={handleChange} />
//
// With onChange handler:
// let (value, setValue) = React.useState(() => "")
// let handleChange = e => {
//   let target = ReactEvent.Form.target(e)
//   setValue(_ => target["value"])
// }
// <UI__Input value={value} onChange={handleChange} />

type inputType = [
  | #text
  | #password
  | #email
  | #number
  | #tel
  | #url
  | #search
  | #date
  | #time
  | #datetime
  | #"datetime-local"
  | #month
  | #week
  | #file
  | #hidden
]

module Input = {
  @module("@/components/ui/input") @react.component
  external make: (
    ~className: string=?,
    ~type_: inputType=?,
    ~placeholder: string=?,
    ~value: string=?,
    ~defaultValue: string=?,
    ~onChange: ReactEvent.Form.t => unit=?,
    ~onBlur: ReactEvent.Focus.t => unit=?,
    ~onFocus: ReactEvent.Focus.t => unit=?,
    ~onKeyDown: ReactEvent.Keyboard.t => unit=?,
    ~onKeyPress: ReactEvent.Keyboard.t => unit=?,
    ~disabled: bool=?,
    ~readOnly: bool=?,
    ~required: bool=?,
    ~autoFocus: bool=?,
    ~autoComplete: string=?,
    ~name: string=?,
    ~id: string=?,
    ~style: {..}=?,
    ~\"aria-label\": string=?,
    ~\"aria-invalid\": bool=?,
  ) => React.element = "Input"
}
