let params1 = URLSearchParams.fromString("foo=1&bar=2")
params1->URLSearchParams.keys->Iterator.toArray->Array.forEach(Console.log)

let params2 = URLSearchParams.fromKeyValueArray([("foo", "1"), ("bar", "b")])
params2->URLSearchParams.values->Iterator.toArray->Array.forEach(Console.log)

let params3 = URLSearchParams.fromDict(dict{"foo": "1", "bar": "b"})
params3
->URLSearchParams.entries
->Iterator.toArray
->Array.forEach(((key, value)) => Console.log2(key, value))

let paramStr = params3->URLSearchParams.toString
