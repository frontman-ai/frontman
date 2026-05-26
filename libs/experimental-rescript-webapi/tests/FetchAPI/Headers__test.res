let h = Headers.make()

h->Headers.set(~name="X-Test", ~value="1")

Headers.fromDict(dict{"X-Vegetable": "Carrot"})->ignore

let h3 = Headers.fromKeyValueArray([("X-Fruit", "Apple"), ("X-Vegetable", "Carrot")])

Console.log(h3->Headers.get("X-Fruit"))
