for i in 0 to DomGlobal.localStorage.length - 1 {
  DomGlobal.localStorage->Storage.key(i)->Null.getOr("nothing")->Console.log
}

let item1 = DomGlobal.localStorage->Storage.getItem("foo")->Null.getOr("nothing")

DomGlobal.localStorage->Storage.setItem(~key="bar", ~value="...")

DomGlobal.localStorage->Storage.removeItem("bar")

DomGlobal.localStorage->Storage.clear
