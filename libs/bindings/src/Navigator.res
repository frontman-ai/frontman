type t = WebAPI.DomTypes.navigator
type shareData = WebAPI.DomTypes.shareData

@get external shareMethod: t => Nullable.t<shareData => promise<unit>> = "share"
@get external canShareMethod: t => Nullable.t<shareData => bool> = "canShare"
@send external canShare: (t, shareData) => bool = "canShare"
@send external share: (t, shareData) => promise<unit> = "share"
