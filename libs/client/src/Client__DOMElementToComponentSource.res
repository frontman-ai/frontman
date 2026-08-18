@@live
type getElementSourceContextResult = {
  success: bool,
  data: option<Client__SourceContext.t>,
  error: option<string>,
}

@module("dom-element-to-component-source")
external getElementSourceContextRaw: (
  ~element: WebAPI.DOMAPI.element,
) => promise<getElementSourceContextResult> = "getElementSourceContext"

let getElementSourceContext = async (~element: WebAPI.DOMAPI.element): option<
  Client__SourceContext.t,
> => {
  let result = await getElementSourceContextRaw(~element)
  switch result.success {
  | true =>
    result.data->Option.map(context => {
      switch context.definition {
      | Some(definition) =>
        switch context.invocations->Array.get(0) {
        | Some(invocation) =>
          switch definition.componentName == invocation.componentName {
          | true =>
            switch invocation.componentProps {
            | Some(componentProps) => {
                ...context,
                definition: Some({...definition, componentProps: Some(componentProps)}),
              }
            | None => context
            }
          | false => context
          }
        | None => context
        }
      | None => context
      }
    })
  | false => None
  }
}
