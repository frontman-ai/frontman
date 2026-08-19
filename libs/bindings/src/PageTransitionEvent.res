type t = WebAPI.EventTypes.event

@get external persisted: t => bool = "persisted"
