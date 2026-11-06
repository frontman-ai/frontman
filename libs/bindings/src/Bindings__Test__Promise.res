@send external finallyAsync: (promise<'a>, unit => promise<unit>) => promise<'a> = "finally"
