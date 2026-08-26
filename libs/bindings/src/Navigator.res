type t = WebAPI.DomTypes.navigator
type shareData = WebAPI.DomTypes.shareData

@get external shareMethod: t => Nullable.t<shareData => promise<unit>> = "share"
@send external share: (t, shareData) => promise<unit> = "share"
