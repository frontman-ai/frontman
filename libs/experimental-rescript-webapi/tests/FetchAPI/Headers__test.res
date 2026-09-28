let h = Headers.make()

h->Headers.set(~name="X-Test", ~value="1")

let h2 = Headers.fromDict(dict{"X-Vegetable": "Carrot"})

let h3 = Headers.fromKeyValueArray([("X-Fruit", "Apple"), ("X-Vegetable", "Carrot")])

Console.log(h3->Headers.get("X-Fruit"))
