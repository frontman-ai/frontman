module Log = FrontmanLogs.Logs.Make({
  let component = #Global
})

type vueComponentType = {
  __file?: string,
  __name?: string,
  name?: string,
  __frontman_templateLine?: int,
}

type rec vueComponentInstance = {
  @as("type") componentType: vueComponentType,
  props: Nullable.t<Dict.t<JSON.t>>,
  parent: Nullable.t<vueComponentInstance>,
}

module VueComponent = {
  let getName = (instance: vueComponentInstance): option<string> => {
    let ct = instance.componentType
    switch ct.__name {
    | Some(n) => Some(n)
    | None =>
      switch ct.name {
      | Some(n) => Some(n)
      | None => ct.__file->Option.map(Client__SourcePath.extractFilename)
      }
    }
  }

  let getFile = (instance: vueComponentInstance): option<string> => instance.componentType.__file

  let getTemplateLine = (instance: vueComponentInstance): int =>
    switch instance.componentType.__frontman_templateLine {
    | Some(l) => l
    | None => 1
    }
}

let getVueComponent: WebAPI.DOMAPI.element => Nullable.t<vueComponentInstance> = %raw(`
  function(el) { return el.__vueParentComponent }
`)

@scope("Array") @val
external isArray: 'a => bool = "isArray"

let findVueInstance = (startElement: WebAPI.DOMAPI.element): option<(
  WebAPI.DOMAPI.element,
  vueComponentInstance,
)> => {
  let el = ref(Some(startElement))
  let depth = ref(0)
  let result = ref(None)

  while el.contents->Option.isSome && depth.contents < 50 && result.contents->Option.isNone {
    let current = el.contents->Option.getOrThrow
    switch getVueComponent(current)->Nullable.toOption {
    | Some(instance) => result := Some((current, instance))
    | None =>
      el := current->WebAPI.Element.parentElement->Null.toOption
      depth := depth.contents + 1
    }
  }

  result.contents
}

let serializeProps = (rawProps: Nullable.t<Dict.t<JSON.t>>): option<Dict.t<JSON.t>> => {
  switch rawProps->Nullable.toOption {
  | None => None
  | Some(props) =>
    let clean = Dict.make()
    let hasProps = ref(false)

    props
    ->Dict.keysToArray
    ->Array.forEach(key => {
      switch key->String.startsWith("__") {
      | true => ()
      | false =>
        switch props->Dict.get(key) {
        | None => ()
        | Some(value) =>
          switch typeof(value) {
          | #string | #number | #boolean =>
            clean->Dict.set(key, value)
            hasProps := true
          | #object =>
            switch (Obj.magic(value): Nullable.t<JSON.t>)->Nullable.toOption {
            | None =>
              clean->Dict.set(key, value)
              hasProps := true
            | Some(_) =>
              let isArr = isArray(value)
              let fallback = switch isArr {
              | true => JSON.String("[Array]")
              | false => JSON.String("{...}")
              }
              let serialized = try {
                switch JSON.stringifyAny(value) {
                | Some(s) =>
                  let maxLen = switch isArr {
                  | true => 1000
                  | false => 500
                  }
                  switch String.length(s) < maxLen {
                  | true => value
                  | false =>
                    switch isArr {
                    | true =>
                      let len = (Obj.magic(value): array<JSON.t>)->Array.length
                      JSON.String(`[Array(${Int.toString(len)})]`)
                    | false => JSON.String("{...}")
                    }
                  }
                | None => fallback
                }
              } catch {
              | _ =>
                Log.warning(`Vue prop serialization failed for key: ${key}`)
                fallback
              }
              clean->Dict.set(key, serialized)
              hasProps := true
            }
          | _ => ()
          }
        }
      }
    })

    switch hasProps.contents {
    | true => Some(clean)
    | false => None
    }
  }
}

let makeSourceLocation = (
  instance: vueComponentInstance,
  element: WebAPI.DOMAPI.element,
  ~parent: option<Client__Types.SourceLocation.t>,
): option<Client__Types.SourceLocation.t> => {
  switch VueComponent.getFile(instance) {
  | None => None
  | Some(file) =>
    switch Client__SourcePath.isNodeModulesPath(file) {
    | true => None
    | false =>
      Some({
        Client__Types.SourceLocation.componentName: VueComponent.getName(instance),
        tagName: element.tagName->String.toLowerCase,
        file,
        line: VueComponent.getTemplateLine(instance),
        column: 1,
        parent,
        componentProps: serializeProps(instance.props),
      })
    }
  }
}

let getElementSourceLocation = (~element: WebAPI.DOMAPI.element): option<
  Client__Types.SourceLocation.t,
> => {
  switch findVueInstance(element) {
  | None => None
  | Some((foundEl, instance)) =>
    let selectedInstance = ref(instance)
    let selectedEl = ref(foundEl)

    switch VueComponent.getFile(instance) {
    | Some(file) if Client__SourcePath.isNodeModulesPath(file) => {
        let current = ref(instance.parent->Nullable.toOption)
        while current.contents->Option.isSome {
          let parentInst = current.contents->Option.getOrThrow
          switch VueComponent.getFile(parentInst) {
          | Some(parentFile) if !Client__SourcePath.isNodeModulesPath(parentFile) =>
            ignore(parentFile)
            selectedInstance := parentInst
            current := None
          | _ => current := parentInst.parent->Nullable.toOption
          }
        }
      }
    | _ => ()
    }

    switch VueComponent.getFile(selectedInstance.contents) {
    | None => None
    | Some(selectedFile) =>
      let parentBoundaries: array<vueComponentInstance> = []
      let lastFile = ref(selectedFile)
      let currentParent = ref(selectedInstance.contents.parent->Nullable.toOption)
      let depth = ref(0)

      while currentParent.contents->Option.isSome && depth.contents < 20 {
        let parentInst = currentParent.contents->Option.getOrThrow
        switch VueComponent.getFile(parentInst) {
        | Some(parentFile)
          if parentFile != lastFile.contents && !Client__SourcePath.isNodeModulesPath(parentFile) =>
          parentBoundaries->Array.push(parentInst)
          lastFile := parentFile
        | _ => ()
        }
        currentParent := parentInst.parent->Nullable.toOption
        depth := depth.contents + 1
      }

      let parentChain = parentBoundaries->Array.reduce(None, (chain, parentInst) => {
        let parentFile = VueComponent.getFile(parentInst)->Option.getOrThrow
        Some({
          Client__Types.SourceLocation.componentName: VueComponent.getName(parentInst),
          tagName: "component",
          file: parentFile,
          line: VueComponent.getTemplateLine(parentInst),
          column: 1,
          parent: chain,
          componentProps: serializeProps(parentInst.props),
        })
      })

      makeSourceLocation(selectedInstance.contents, selectedEl.contents, ~parent=parentChain)
    }
  }
}
