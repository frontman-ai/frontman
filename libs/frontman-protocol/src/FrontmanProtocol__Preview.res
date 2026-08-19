type errorCode = string

type error = {
  code: errorCode,
  message: string,
}

type Types.message<_> +=
  | Ready: Types.message<unit>
