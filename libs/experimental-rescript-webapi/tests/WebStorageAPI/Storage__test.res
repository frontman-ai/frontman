open Global
open WebAPI.Storage

for i in 0 to localStorage.length - 1 {
  localStorage->key(i)->Null.getOr("nothing")->Console.log
}

let item1 = localStorage->getItem("foo")->Null.getOr("nothing")

localStorage->setItem(~key="bar", ~value="...")

localStorage->removeItem("bar")

localStorage->clear
